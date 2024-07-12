// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FlowTreeLib.sol";
import "../utils/IDigestHistory.sol";
import "../utils/Initializable.sol";
import "../utils/DigestHistory.sol";
import "../utils/ZgsSpec.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";
import "../security/PauseControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Flow is IFlow, PauseControl, Initializable {
    using SubmissionLibrary for Submission;
    using SafeERC20 for IERC20;
    using FlowTreeLib for FlowTree;

    // immutables
    uint private constant MAX_DEPTH = 64;
    uint private constant ROOT_AVAILABLE_WINDOW = 20;

    bytes32 private constant EMPTY_HASH = hex"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

    IDigestHistory public immutable rootHistory;
    uint public immutable blocksPerEpoch;
    uint public immutable firstBlock;

    // states
    address payable public market;

    FlowTree public tree;
    uint[50] private __gap;

    uint public submissionIndex;
    uint public epoch;
    uint public epochStartPosition;

    MineContext private context;
    mapping(bytes32 => EpochRange) private epochRanges;
    EpochRangeWithContextDigest[] private epochRangeHistory;

    error InvalidSubmission();

    constructor(uint blocksPerEpoch_, uint deployDelay_) {
        blocksPerEpoch = blocksPerEpoch_;
        rootHistory = new DigestHistory(ROOT_AVAILABLE_WINDOW);
        firstBlock = block.number + deployDelay_;
    }

    function _initialize(address market_) internal virtual {
        // initialize incremental merkle tree
        tree.initialize(bytes32(0x0));
        // initialize flow
        market = payable(market_);

        epoch = 0;

        context = MineContext({
            epoch: 0,
            mineStart: firstBlock,
            flowRoot: tree.root(),
            flowLength: 1,
            blockDigest: EMPTY_HASH,
            digest: EMPTY_HASH
        });
        // initialize admin and pause control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    function initialize(address market_) public virtual onlyInitializeOnce {
        _initialize(market_);
    }

    modifier launched() {
        require(block.number >= firstBlock, "Contract has not launched.");
        _;
    }

    function batchSubmit(
        Submission[] memory submissions
    )
        public
        payable
        whenNotPaused
        launched
        returns (uint[] memory indexes, bytes32[] memory digests, uint[] memory startIndexes, uint[] memory lengths)
    {
        uint len = submissions.length;
        indexes = new uint[](len);
        digests = new bytes32[](len);
        startIndexes = new uint[](len);
        lengths = new uint[](len);
        for (uint i = 0; i < len; ++i) {
            (uint index, bytes32 digest, uint startIndex, uint length) = submit(submissions[i]);
            indexes[i] = index;
            digests[i] = digest;
            startIndexes[i] = startIndex;
            lengths[i] = length;
        }
    }

    function _beforeSubmit(uint sectors) internal virtual {}

    function submit(
        Submission memory submission
    ) public payable whenNotPaused launched returns (uint, bytes32, uint, uint) {
        require(submission.valid(), "Invalid submission");

        uint length = submission.size();
        _beforeSubmit(length);

        makeContext();

        uint startIndex = _insertNodeList(submission);

        bytes32 digest = submission.digest();
        uint index = submissionIndex;
        submissionIndex += 1;

        emit Submit(msg.sender, digest, index, startIndex, length, submission);

        return (index, digest, startIndex, length);
    }

    function _insertNodeList(Submission memory submission) internal returns (uint startIndex) {
        uint previousLength = tree.currentLength;
        for (uint i = 0; i < submission.nodes.length; i++) {
            bytes32 nodeRoot = submission.nodes[i].root;
            uint height = submission.nodes[i].height;
            uint nodeStartIndex = tree.insertNode(nodeRoot, height);
            if (i == 0) {
                startIndex = nodeStartIndex;
            }
        }

        uint paddedLength = startIndex - previousLength;
        uint chargedLength = tree.currentLength - startIndex;

        IMarket(market).chargeFee(previousLength, chargedLength, paddedLength);
    }

    function _makeContext() internal returns (bool) {
        uint nextEpochStart;
        unchecked {
            nextEpochStart = firstBlock + (epoch + 1) * blocksPerEpoch;
        }

        if (nextEpochStart >= block.number) {
            return false;
        }
        tree.commitRoot();
        bytes32 currentRoot = tree.root();
        uint index = rootHistory.insert(currentRoot);
        assert(index == epoch);

        bytes32 contextDigest;
        bytes32 blockDigest;

        if (nextEpochStart + 256 < block.number) {
            contextDigest = EMPTY_HASH;
            blockDigest = EMPTY_HASH;
        } else {
            blockDigest = blockhash(nextEpochStart);
            contextDigest = keccak256(abi.encode(blockDigest, currentRoot, tree.currentLength));

            uint128 startPosition = uint128(epochStartPosition);
            uint128 endPosition = uint128(tree.currentLength);
            epochRanges[contextDigest] = EpochRange({start: startPosition, end: endPosition});
            epochRangeHistory.push(
                EpochRangeWithContextDigest({start: startPosition, end: endPosition, digest: contextDigest})
            );

            epochStartPosition = tree.currentLength;
        }

        epoch += 1;

        context = MineContext({
            epoch: epoch,
            mineStart: nextEpochStart,
            flowRoot: currentRoot,
            flowLength: tree.currentLength,
            blockDigest: blockDigest,
            digest: contextDigest
        });

        emit NewEpoch(msg.sender, epoch, currentRoot, submissionIndex, tree.currentLength, contextDigest);
        return true;
    }

    function makeContext() public launched {
        while (_makeContext()) {}
    }

    function makeContextFixedTimes(uint cnt) public launched {
        for (uint i = 0; i <= cnt; ++i) {
            if (!_makeContext()) {
                return;
            }
        }
    }

    function queryContextAtPosition(
        uint128 targetPosition
    ) external returns (EpochRangeWithContextDigest memory range) {
        makeContext();
        require(targetPosition < tree.currentLength, "Queried position exceeds upper bound");
        uint minIndex = 0;
        uint maxIndex = epochRangeHistory.length;
        while (maxIndex > minIndex) {
            uint curIndex = (maxIndex + minIndex) / 2;
            range = epochRangeHistory[curIndex];
            if (targetPosition >= range.end) {
                minIndex = curIndex + 1;
            } else if (targetPosition >= range.start) {
                return range;
            } else {
                // If curIndex == 0, the function will be reverted as expected.
                maxIndex = curIndex;
            }
        }
        require(false, "Can not find proper context");
    }

    function makeContextWithResult() external launched returns (MineContext memory) {
        makeContext();
        return getContext();
    }

    function getContext() public view returns (MineContext memory) {
        MineContext memory _context = context;
        return _context;
    }

    function getEpochRange(bytes32 digest) external view returns (EpochRange memory) {
        return epochRanges[digest];
    }

    function numSubmissions() external view returns (uint) {
        return submissionIndex;
    }
}

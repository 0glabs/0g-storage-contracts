// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

pragma solidity ^0.8.0;

import "./FlowTreeLib.sol";
import "../utils/DigestHistory.sol";
import "../utils/ZgsSpec.sol";
import "../utils/BlockHash.sol";
import "../interfaces/IDigestHistory.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";
import "../security/PauseControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Flow is IFlow, PauseControl {
    using SubmissionLibrary for Submission;
    using SafeERC20 for IERC20;
    using FlowTreeLib for FlowTree;

    // immutables
    uint private constant MAX_DEPTH = 64;
    uint private constant ROOT_AVAILABLE_WINDOW = 1000;

    bytes32 private constant EMPTY_HASH = hex"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

    uint public immutable deployDelay;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    /// @custom:storage-location erc7201:0g.storage.Flow
    struct FlowStorage {
        address payable market;
        FlowTree tree;
        uint submissionIndex;
        uint epoch;
        uint epochStartPosition;
        MineContext context;
        mapping(bytes32 => EpochRange) epochRanges;
        EpochRangeWithContextDigest[] epochRangeHistory;
        mapping(uint => bytes32) rootByTxSeq;
        uint firstBlock;
        IDigestHistory rootHistory;
        uint blocksPerEpoch;
    }

    // keccak256(abi.encode(uint(keccak256("0g.storage.Flow")) - 1)) & ~bytes32(uint(0xff))
    bytes32 private constant FlowStorageLocation = 0x2c76cc46aac583da4777117fb4419fbb43af6051f6353fccbce7a36d394f5500;

    function _getFlowStorage() private pure returns (FlowStorage storage $) {
        assembly {
            $.slot := FlowStorageLocation
        }
    }

    error InvalidSubmission();

    constructor(uint deployDelay_) {
        deployDelay = deployDelay_;
    }

    function _initialize(address market_) internal virtual {
        FlowStorage storage $ = _getFlowStorage();

        // initialize incremental merkle tree
        $.tree.initialize(bytes32(0x0));
        // initialize flow
        $.market = payable(market_);

        $.epoch = 0;

        $.context = MineContext({
            epoch: 0,
            mineStart: $.firstBlock,
            flowRoot: $.tree.root(),
            flowLength: 1,
            blockDigest: EMPTY_HASH,
            digest: EMPTY_HASH
        });
        // initialize admin and pause control
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    function initialize(address market_, uint blocksPerEpoch_) public virtual initializer {
        _initialize(market_);
        _setParams(blocksPerEpoch_, block.number + deployDelay, address(new DigestHistory(ROOT_AVAILABLE_WINDOW)));
    }

    /*=== view functions ===*/

    function market() public view returns (address payable) {
        return _getFlowStorage().market;
    }

    function tree() public view returns (uint currentLength, uint unstagedHeight) {
        FlowTree memory t = _getFlowStorage().tree;
        return (t.currentLength, t.unstagedHeight);
    }

    function submissionIndex() public view returns (uint) {
        return _getFlowStorage().submissionIndex;
    }

    function epoch() public view returns (uint) {
        return _getFlowStorage().epoch;
    }

    function epochStartPosition() public view returns (uint) {
        return _getFlowStorage().epochStartPosition;
    }

    function getContext() public view returns (MineContext memory) {
        return _getFlowStorage().context;
    }

    function getEpochRange(bytes32 digest) public view returns (EpochRange memory) {
        return _getFlowStorage().epochRanges[digest];
    }

    function getEpochRangeHistory(uint index) public view returns (EpochRangeWithContextDigest memory) {
        return _getFlowStorage().epochRangeHistory[index];
    }

    function getFlowRootByTxSeq(uint txSeq) public view returns (bytes32) {
        return _getFlowStorage().rootByTxSeq[txSeq];
    }

    function firstBlock() public view returns (uint) {
        return _getFlowStorage().firstBlock;
    }

    function rootHistory() public view returns (IDigestHistory) {
        return _getFlowStorage().rootHistory;
    }

    function blocksPerEpoch() public view returns (uint) {
        return _getFlowStorage().blocksPerEpoch;
    }

    /*=== main ===*/

    function setParams(uint blocksPerEpoch_, uint firstBlock_, address rootHistory_) external {
        _setParams(blocksPerEpoch_, firstBlock_, rootHistory_);
    }

    function _setParams(uint blocksPerEpoch_, uint firstBlock_, address rootHistory_) internal {
        FlowStorage storage $ = _getFlowStorage();
        if ($.blocksPerEpoch == 0) {
            $.blocksPerEpoch = blocksPerEpoch_;
        }
        if ($.firstBlock == 0) {
            $.firstBlock = firstBlock_;
        }
        if (address($.rootHistory) == address(0)) {
            if (rootHistory_ == address(0)) {
                $.rootHistory = new DigestHistory(ROOT_AVAILABLE_WINDOW);
            } else {
                $.rootHistory = IDigestHistory(rootHistory_);
            }
        }
    }

    modifier launched() {
        FlowStorage storage $ = _getFlowStorage();
        require(block.number >= $.firstBlock, "Contract has not launched.");
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
    ) public payable whenNotPaused launched returns (uint index, bytes32, uint, uint) {
        FlowStorage storage $ = _getFlowStorage();
        require(submission.valid(), "Invalid submission");

        uint length = submission.size();
        _beforeSubmit(length);

        makeContext();

        uint startIndex = _insertNodeList(submission);

        bytes32 digest = submission.digest();
        index = $.submissionIndex;
        $.submissionIndex += 1;

        $.tree.commitRoot();
        $.rootByTxSeq[index] = $.tree.root();

        emit Submit(msg.sender, digest, index, startIndex, length, submission);

        return (index, digest, startIndex, length);
    }

    function _insertNodeList(Submission memory submission) internal returns (uint startIndex) {
        FlowStorage storage $ = _getFlowStorage();
        uint previousLength = $.tree.currentLength;
        $.tree.pad(submission);
        for (uint i = 0; i < submission.nodes.length; i++) {
            bytes32 nodeRoot = submission.nodes[i].root;
            uint height = submission.nodes[i].height;
            uint nodeStartIndex = $.tree.insertNode(nodeRoot, height);
            if (i == 0) {
                startIndex = nodeStartIndex;
            }
        }

        uint paddedLength = startIndex - previousLength;
        uint chargedLength = $.tree.currentLength - startIndex;

        IMarket($.market).chargeFee(previousLength, chargedLength, paddedLength);
    }

    function _makeContext() internal whenNotPaused returns (bool) {
        FlowStorage storage $ = _getFlowStorage();

        uint nextEpochStart;
        unchecked {
            nextEpochStart = $.firstBlock + ($.epoch + 1) * $.blocksPerEpoch;
        }

        if (nextEpochStart >= block.number) {
            return false;
        }
        $.tree.commitRoot();
        bytes32 currentRoot = $.tree.root();
        $.rootHistory.insert(currentRoot);
        // assert(index == epoch);

        bytes32 contextDigest;
        bytes32 blockDigest;

        if (nextEpochStart + 8191 < block.number) {
            contextDigest = EMPTY_HASH;
            blockDigest = EMPTY_HASH;
        } else {
            blockDigest = Blockhash.blockHash(nextEpochStart);
            contextDigest = keccak256(abi.encode(blockDigest, currentRoot, $.tree.currentLength));

            uint128 startPosition = uint128($.epochStartPosition);
            uint128 endPosition = uint128($.tree.currentLength);
            $.epochRanges[contextDigest] = EpochRange({start: startPosition, end: endPosition});
            $.epochRangeHistory.push(
                EpochRangeWithContextDigest({start: startPosition, end: endPosition, digest: contextDigest})
            );

            $.epochStartPosition = $.tree.currentLength;
        }

        $.epoch += 1;

        $.context = MineContext({
            epoch: $.epoch,
            mineStart: nextEpochStart,
            flowRoot: currentRoot,
            flowLength: $.tree.currentLength,
            blockDigest: blockDigest,
            digest: contextDigest
        });

        emit NewEpoch(msg.sender, $.epoch, currentRoot, $.submissionIndex, $.tree.currentLength, contextDigest);
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
        FlowStorage storage $ = _getFlowStorage();

        makeContext();
        require(targetPosition < $.tree.currentLength, "Queried position exceeds upper bound");
        uint minIndex = 0;
        uint maxIndex = $.epochRangeHistory.length;
        while (maxIndex > minIndex) {
            uint curIndex = (maxIndex + minIndex) / 2;
            range = $.epochRangeHistory[curIndex];
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

    function computeFlowRoot() public returns (bytes32) {
        FlowStorage storage $ = _getFlowStorage();
        $.tree.commitRoot();
        return $.tree.root();
    }

    function numSubmissions() external view returns (uint) {
        FlowStorage storage $ = _getFlowStorage();
        return $.submissionIndex;
    }
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IncrementalMerkleTree.sol";
import "../utils/IDigestHistory.sol";
import "../utils/DigestHistory.sol";
import "../utils/ZgsSpec.sol";
import "../interfaces/IMarket.sol";
import "../interfaces/IReward.sol";
import "../interfaces/IFlow.sol";
import "../interfaces/AddressBook.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Flow is Pausable, IFlow, IncrementalMerkleTree {
    using SubmissionLibrary for Submission;
    using SafeERC20 for IERC20;

    uint256 private constant MAX_DEPTH = 64;
    uint256 private constant ROOT_AVAILABLE_WINDOW = 20;

    bytes32 private constant EMPTY_HASH =
        hex"c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470";

    AddressBook public immutable book;
    IDigestHistory public immutable rootHistory;
    uint256 public immutable blocksPerEpoch;
    uint256 public immutable firstBlock;

    uint256 public submissionIndex;
    uint256 public epoch;
    uint256 public epochStartPosition;

    MineContext private context;
    mapping(bytes32 => EpochRange) private epochRanges;
    EpochRangeWithContextDigest[] private epochRangeHistory;

    error InvalidSubmission();

    constructor(
        address book_,
        uint256 blocksPerEpoch_,
        uint256 deployDelay_
    ) IncrementalMerkleTree(bytes32(0x0)) {
        epoch = 0;
        blocksPerEpoch = blocksPerEpoch_;
        rootHistory = new DigestHistory(ROOT_AVAILABLE_WINDOW);
        firstBlock = block.number + deployDelay_;

        book = AddressBook(book_);

        context = MineContext({
            epoch: 0,
            mineStart: firstBlock,
            flowRoot: root(),
            flowLength: 1,
            blockDigest: EMPTY_HASH,
            digest: EMPTY_HASH
        });
    }

    modifier launched() {
        require(block.number >= firstBlock, "Contract has not launched.");
        _;
    }

    function batchSubmit(Submission[] memory submissions)
        public
        payable
        whenNotPaused
        launched
        returns (
            uint256[] memory indexes,
            bytes32[] memory digests,
            uint256[] memory startIndexes,
            uint256[] memory lengths
        )
    {
        uint256 len = submissions.length;
        indexes = new uint256[](len);
        digests = new bytes32[](len);
        startIndexes = new uint256[](len);
        lengths = new uint256[](len);
        for (uint256 i = 0; i < len; ++i) {
            (
                uint256 index,
                bytes32 digest,
                uint256 startIndex,
                uint256 length
            ) = submit(submissions[i]);
            indexes[i] = index;
            digests[i] = digest;
            startIndexes[i] = startIndex;
            lengths[i] = length;
        }
    }

    function _beforeSubmit(uint256 sectors) internal virtual {}

    function submit(Submission memory submission)
        public
        payable
        whenNotPaused
        launched
        returns (
            uint256,
            bytes32,
            uint256,
            uint256
        )
    {
        require(submission.valid(), "Invalid submission");

        uint256 length = submission.size();
        _beforeSubmit(length);

        makeContext();

        uint256 startIndex = _insertNodeList(submission);

        bytes32 digest = submission.digest();
        uint256 index = submissionIndex;
        submissionIndex += 1;

        emit Submit(msg.sender, digest, index, startIndex, length, submission);

        return (index, digest, startIndex, length);
    }

    function _insertNodeList(Submission memory submission)
        internal
        returns (uint256 startIndex)
    {
        uint256 previousLength = currentLength;
        for (uint256 i = 0; i < submission.nodes.length; i++) {
            bytes32 nodeRoot = submission.nodes[i].root;
            uint256 height = submission.nodes[i].height;
            uint256 nodeStartIndex = _insertNode(nodeRoot, height);
            if (i == 0) {
                startIndex = nodeStartIndex;
            }
        }

        uint256 paddedLength = startIndex - previousLength;
        uint256 chargedLength = currentLength - startIndex;

        book.market().chargeFee(previousLength, chargedLength, paddedLength);
    }

    function makeContext() public launched {
        uint256 nextEpochStart;
        unchecked {
            nextEpochStart = firstBlock + (epoch + 1) * blocksPerEpoch;
        }

        if (nextEpochStart >= block.number) {
            return;
        }
        commitRoot();
        bytes32 currentRoot = root();
        uint256 index = rootHistory.insert(currentRoot);
        assert(index == epoch);

        bytes32 contextDigest;
        bytes32 blockDigest;

        if (nextEpochStart + 256 < block.number) {
            contextDigest = EMPTY_HASH;
            blockDigest = EMPTY_HASH;
        } else {
            blockDigest = blockhash(nextEpochStart);
            contextDigest = keccak256(
                abi.encode(blockDigest, currentRoot, currentLength)
            );

            uint128 startPosition = uint128(epochStartPosition);
            uint128 endPosition = uint128(currentLength);
            epochRanges[contextDigest] = EpochRange({
                start: startPosition,
                end: endPosition
            });
            epochRangeHistory.push(
                EpochRangeWithContextDigest({
                    start: startPosition,
                    end: endPosition,
                    digest: contextDigest
                })
            );

            epochStartPosition = currentLength;
        }

        epoch += 1;

        context = MineContext({
            epoch: epoch,
            mineStart: nextEpochStart,
            flowRoot: currentRoot,
            flowLength: currentLength,
            blockDigest: blockDigest,
            digest: contextDigest
        });

        emit NewEpoch(
            msg.sender,
            epoch,
            currentRoot,
            submissionIndex,
            currentLength,
            contextDigest
        );

        // TODO: send reward to incentivize make context.

        // Recursive call to handle a rare case: the contract is more than one epoch behind.
        makeContext();
    }

    function queryContextAtPosition(uint128 targetPosition)
        external
        returns (EpochRangeWithContextDigest memory range)
    {
        makeContext();
        require(
            targetPosition < currentLength,
            "Queried position exceeds upper bound"
        );
        uint256 minIndex = 0;
        uint256 maxIndex = epochRangeHistory.length;
        while (maxIndex > minIndex) {
            uint256 curIndex = (maxIndex + minIndex) / 2;
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

    function makeContextWithResult()
        external
        launched
        returns (MineContext memory)
    {
        makeContext();
        return getContext();
    }

    function getContext() public view returns (MineContext memory) {
        MineContext memory _context = context;
        return _context;
    }

    function getEpochRange(bytes32 digest)
        external
        view
        returns (EpochRange memory)
    {
        return epochRanges[digest];
    }

    function numSubmissions() external view returns (uint256) {
        return submissionIndex;
    }
}

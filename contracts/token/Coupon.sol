// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/OnlySender.sol";
import "./ISafeERC20.sol";

contract Coupon is ERC721, Ownable, OnlySender {
    event Fuel(uint256 indexed tokenId, uint256 amount);
    event Consume(
        uint256 indexed tokenId,
        address indexed user,
        uint256 amount
    );
    event Revoke(uint256 indexed tokenId, uint256 amount);

    ISafeERC20 public immutable zgsToken;
    address public immutable cashier;

    mapping(uint256 => uint256) public uploadBalance;
    uint256 public totalUnusedBalance;
    uint256 public nextTokenId;

    uint256 private constant BASIC_PRICE = 1000;

    constructor(address zgsToken_, address cashier_)
        ERC721("ZeroGStorageCoupon", "ZGS-CPN")
    {
        zgsToken = ISafeERC20(zgsToken_);
        cashier = cashier_;
        nextTokenId = 1;
    }

    function mint(address to) external onlyOwner returns (uint256) {
        uint256 tokenId = nextTokenId;
        _mint(to, tokenId);
        nextTokenId += 1;
        return tokenId;
    }

    function fuel(uint256 tokenId, uint256 amount) public onlyOwner {
        require(_exists(tokenId), "coupon does not exist");
        require(amount <= totalUnusedBalance, "no capacity");

        totalUnusedBalance -= amount;
        zgsToken.transferFrom(msg.sender, cashier, amount * BASIC_PRICE);
        uploadBalance[tokenId] += amount;

        emit Fuel(tokenId, amount);
    }

    function pay(
        address requester,
        uint256 tokenId,
        uint256 amount
    ) external {
        require(msg.sender == cashier, "Only cashier can call");
        require(ownerOf(tokenId) == requester, "Requester not own this token");

        uploadBalance[tokenId] -= amount;
        totalUnusedBalance += amount;

        emit Consume(tokenId, requester, amount);
    }

    function revoke(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "coupon does not exist");

        uint256 amount = uploadBalance[tokenId];
        zgsToken.transferFrom(cashier, msg.sender, amount * BASIC_PRICE);
        uploadBalance[tokenId] = 0;
        totalUnusedBalance += amount;

        emit Revoke(tokenId, amount);
    }
}

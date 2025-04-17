// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../../utils/OnlySender.sol";
import "../../token/ISafeERC20.sol";

contract Coupon is ERC721, Ownable, OnlySender {
    event Fuel(uint indexed tokenId, uint amount);
    event Consume(uint indexed tokenId, address indexed user, uint amount);
    event Revoke(uint indexed tokenId, uint amount);

    ISafeERC20 public immutable zgsToken;
    address public immutable cashier;

    mapping(uint => uint) public uploadBalance;
    uint public totalUnusedBalance;
    uint public nextTokenId;

    uint private constant BASIC_PRICE = 1000;

    constructor(address zgsToken_, address cashier_) ERC721("ZeroGStorageCoupon", "ZGS-CPN") Ownable(msg.sender) {
        zgsToken = ISafeERC20(zgsToken_);
        cashier = cashier_;
        nextTokenId = 1;
    }

    function mint(address to) external onlyOwner returns (uint) {
        uint tokenId = nextTokenId;
        _mint(to, tokenId);
        nextTokenId += 1;
        return tokenId;
    }

    function fuel(uint tokenId, uint amount) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "coupon does not exist");
        require(amount <= totalUnusedBalance, "no capacity");

        totalUnusedBalance -= amount;
        zgsToken.transferFrom(msg.sender, cashier, amount * BASIC_PRICE);
        uploadBalance[tokenId] += amount;

        emit Fuel(tokenId, amount);
    }

    function pay(address requester, uint tokenId, uint amount) external {
        require(msg.sender == cashier, "Only cashier can call");
        require(_ownerOf(tokenId) == requester, "Requester not own this token");

        uploadBalance[tokenId] -= amount;
        totalUnusedBalance += amount;

        emit Consume(tokenId, requester, amount);
    }

    function revoke(uint tokenId) public onlyOwner {
        require(_ownerOf(tokenId) != address(0), "coupon does not exist");

        uint amount = uploadBalance[tokenId];
        zgsToken.transferFrom(cashier, msg.sender, amount * BASIC_PRICE);
        uploadBalance[tokenId] = 0;
        totalUnusedBalance += amount;

        emit Revoke(tokenId, amount);
    }
}

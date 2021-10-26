// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FpERC721 is ERC721, Ownable {

    mapping(uint256 => uint256) combinedMintAmount;
    address fpCouponAddr;

    modifier onlyFpCoupon() {
        require(msg.sender == fpCouponAddr, "only allowed by FpCoupon");
        _;
    }

    constructor() public ERC721("NFT of dFuture", "dNFT") {

    }

    function setFpCouponAddr(address fpCoupon) public onlyOwner {
        fpCouponAddr = fpCoupon;
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public onlyOwner {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        _setBaseURI(baseURI_);
    }

    function countOf(uint256 target) public view returns(uint256) {
        return combinedMintAmount[target];
    }

    function mintByFpCoupon(uint256 target, address to, uint256 id) public onlyFpCoupon {
        combinedMintAmount[target] += 1;

        _mint(to, id);
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function transfer(address to, uint256 tokenId) public {
        _transfer(msg.sender, to, tokenId);
    }
}

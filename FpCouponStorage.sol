// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "./FpNFT.sol";

contract FpCouponStorage {
    address fpErc1155Addr; // FpERC1155合约地址
    address contractOwner;
    address futurePerpetualAddr; // FP合约地址

    mapping(address => bool) admins;
    mapping(address => bool) relayers;

    mapping(uint256 => uint8) transferables; // 各种卡类型是否可以transfer
    mapping(uint256 => uint256) mintableAmount; // 各种卡类型允许铸造的上限数量
    mapping(uint256 => uint256) mintedAmount; // 各种卡已经铸造的数量
    mapping(uint256 => uint256) usableMinValue; // 各功能卡使用时的min value
    mapping(uint256 => uint256) usableMaxValue; // 各功能卡使用时的max value

    mapping(uint256 => FpNFT.Coupon) couponCollection; // 所有已经发出的卡集合

    // address => tokenId => amount
    mapping(address => mapping(uint256 => uint256)) minterMintedAmount; // 有铸币权的人已经铸造出的数量
    mapping(address => mapping(uint256 => uint256)) minterMintableAmount; // 有铸币权的人各类币可铸造的数量

    mapping(bytes32 => bool) MintOperationRecords; // 记录mint操作, 防重放.

    uint8 maxLuckyBoxRanges; // 默认最多开盲盒分10个区间, 是否有必要灵活?
    // 盲盒Id => 区间 => 参数
    mapping(uint256 => mapping(uint8 => FpNFT.LuckyBoxMetaData)) luckyBoxMetaData; // 开盲盒的参数设置
    // 铸造721时使用的base tokenId => .....
    mapping(uint256 => FpNFT.CombinedMetaData[]) combinedMetaData;

    address fpErc721Addr;

    modifier onlyOwner() {
        require(msg.sender == contractOwner, "only owner allowed");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender], "only admin allowed");
        _;
    }

    modifier onlyFP() {
        require(
            msg.sender == futurePerpetualAddr,
            "only FP allowed"
        );
        _;
    }

    modifier onlyAllowedRoles() {
        require(
            msg.sender == contractOwner ||
            msg.sender == futurePerpetualAddr ||
            admins[msg.sender] ||
            relayers[msg.sender],
            "it is not an allowed sender"
        );
        _;
    }

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "only EOA allowed");
        _;
    }

    event CouponMinted(
        address indexed minter,
        address indexed to,
        uint256 tokenId,
        uint256 amount,
        uint256 data,
        bytes32 label,
        bytes32 minthash
    );

    event CouponBatchMinted(
        address indexed minter,
        address indexed to,
        uint256[] tokenIds,
        uint256[] amounts,
        uint256[] dataes,
        bytes32[] labels,
        bytes32 minthash
    );

    event CouponBurned(
        address indexed owner,
        uint256 tokenId,
        uint8 reason
    );

    event CouponUsed(
        address indexed owner,
        uint256 tokenId,
        uint256 amount
    );

    event CouponTransfered(
        address indexed who,
        address indexed from,
        address indexed to,
        uint256 tokenId,
        uint256 amount
    );

    event CouponBatchTransfered(
        address indexed from,
        address indexed to,
        uint256[] tokenIds,
        uint256[] amounts
    );

    event LuckyBoxMinted(
        address indexed to,
        uint256 boxId,
        uint8 reason
    );

    event LuckyBoxOpened(
        address indexed from,
        uint256 boxId,
        uint256 mintedCouponId
    );

    event LuckyBoxTransfered(
        address indexed from,
        address indexed to,
        uint256[] boxIds,
        uint256[] boxAmounts
    );

    event CouponCombined(
        address indexed from,
        uint256 target,
        uint256[] usedCoupons,
        uint256 card721Id
    );
}
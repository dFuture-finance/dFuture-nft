// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

library FpNFT {
    // 设定卡类型
    uint8 constant CouponType_Common = 1; // 体验类
    uint8 constant CouponType_Scarce = 2; // 权益类
    uint8 constant CouponType_Assist = 3; // 辅助类
    uint8 constant CouponType_LuckyBox = 4; // 盲盒类

    // 设定身份/来源
    uint8 constant CouponIdentity_Newer   = 1; // 新人
    uint8 constant CouponIdentity_Common  = 2; // 普通人
    uint8 constant CouponIdentity_KOL     = 3; // KOL专属
    uint8 constant CouponIdentity_Inviter = 4; // 邀请人(普通人)

    // 设定功能
    uint8 constant CouponFunc_Fee         = 1; // 减免手续费
    uint8 constant CouponFunc_TradeMining = 2; // 交易挖矿翻倍
    uint8 constant CouponFunc_Leverage    = 3; // 杠杆卡
    uint8 constant CouponFunc_Delay       = 4; // 延时卡
    uint8 constant CouponFunc_Universal   = 5; // 万能卡

    uint8 constant CouponFunc_Total = 6; // Coupon的所有功能, 需要放在最后定义

    // 盲盒不算在功能卡里面
    uint8 constant CouponFunc_LuckyBox_Common   = 200; // 普通盲盒
    uint8 constant CouponFunc_LuckyBox_Scarce   = 201; // 稀有盲盒

    // 卡销毁原因
    uint8 constant CouponBurn_UsableTimesOut = 1; // 无可使用次数
    uint8 constant CouponBurn_OverDeadline = 2; // 过期
    uint8 constant CouponBurn_Merged = 3; // 被合并为新卡

    struct Coupon {
        uint256 tokenId; // 合约内部使用的id编号

        // 卡片功能参数:
        // 1. 手续费减免卡, 表示减免比例
        // 2. 挖矿翻倍卡, 表示翻倍倍数
        // 3. 杠杆卡, 表示允许最大的杠杆
        // 4. 延时卡,
        uint256 data;
        // 可使用的仓位上下限
        uint256 limitMin;
        uint256 limitMax;
        // 名称
        bytes32 label;
        // 是否可转让
        bool transferable;
    }

    // 开盲盒时, 铸币用到的参数
    struct LuckyBoxMetaData {
        uint8 rangeStart; // 计算概率时使用的范围, 如果随机数落在[start, end)范围内, 则使用这个参数铸币
        uint8 rangeEnd;
        uint16 maxCount; // 该类型的币最大允许的铸造数量.
        uint16 mintedCount; // 已经铸造的数量

        uint256 tokenId; // 命中时能够获取的tokenId
        uint256 data; // coupon 的参数
        bytes32 label;
    }

    // 合成Coupon的设置参数, 功能, 身份, 数量都匹配上时, 才认为符合条件
    struct CombinedMetaData {
        uint8 func; // 功能
        uint8 identity; // 身份
        uint8 amount; // 数量
    }

    function compositeCouponId(uint8 dtype, uint8 identity, uint8 func, uint16 batchno, uint16 no, uint32 deadline)
        internal
        pure
        returns(uint256)
    {
        uint256 couponId;
        couponId = (couponId | (uint256(dtype) << 80));
        couponId = (couponId | (uint256(identity) << 72));
        couponId = (couponId | (uint256(func) << 64));
        couponId = (couponId | (uint256(batchno) << 48));
        couponId = (couponId | (uint256(no) << 32));
        couponId = (couponId | (uint256(deadline)));
        return couponId;
    }

    function getCouponType(uint256 tokenId) internal pure returns(uint8) {

        return uint8(tokenId >> 80 & 0xff);
    }

    function getCouponIdentity(uint256 tokenId) internal pure returns(uint8) {
        return uint8((tokenId >> 72) & 0xff);
    }

    function getCouponDeadline(uint256 tokenId) internal pure returns(uint32) {
        return uint32(tokenId & 0xffffffff);
    }

    function getCouponFunc(uint256 tokenId) internal pure returns(uint8) {
        return uint8(tokenId >> 64 & 0xff);
    }
}

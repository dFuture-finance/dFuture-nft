// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/Initializable.sol";
import "./FpCouponStorage.sol";
import "./FpNFT.sol";
import "./FpERC1155.sol";
import "./FpERC721.sol";

import {MixedMath} from "../lib/MixedMath.sol";

contract FpCoupon is FpCouponStorage, Initializable {
    using MixedMath for uint256;
    using MixedMath for int256;

    function initialize() public initializer {
        contractOwner = msg.sender;
    }

    function setAdmins(address admin, bool asAdmin) public onlyOwner {
        admins[admin] = asAdmin;
    }

    function setRelayer(address relayer, bool asrelayer) public onlyAdmin {
        relayers[relayer] = asrelayer;
    }

    function getContractOwner() public view returns(address) {
        return contractOwner;
    }

    // 设置某一类功能卡使用时的仓位大小限制, 如果无须限制, 将min, max设置为0
    function setUsableLimitValue(
        uint256 tokenId,
        uint256 min,
        uint256 max
    )
        public
        onlyAdmin
    {
        usableMinValue[tokenId] = min;
        usableMaxValue[tokenId] = max;

        if (couponCollection[tokenId].tokenId != 0) {
            couponCollection[tokenId].limitMin = min;
            couponCollection[tokenId].limitMax = max;
        }
    }

    function  getUsableLimitValue(
        uint256 tokenId
    )
        public
        view
        returns(uint256 min, uint256 max)
    {
        min = usableMinValue[tokenId];
        max = usableMaxValue[tokenId];
    }

    // 设置FuturePerpetual合约地址
    function setFuturePerpetual(address fp) public onlyAdmin
    {
        futurePerpetualAddr = fp;
    }
    // 设置ERC1155的地址
    function setErc1155Address(address fp1155) public onlyAdmin {
        fpErc1155Addr = fp1155;
    }

    // 设置ERC721的地址
    function setErc721Address(address fp721) public onlyAdmin {
        fpErc721Addr = fp721;
    }

    // set coupon data
    function getCouponInfo(uint256 tokenId) public view returns(FpNFT.Coupon memory) {
        return couponCollection[tokenId];
    }

    function setCouponData(uint256 tokenId, uint256 data) public onlyAdmin {
        if (couponCollection[tokenId].tokenId != 0) {
            couponCollection[tokenId].data = data;
        }
    }

    // 设置某一类卡的是否可以转移
    function setTransferables(uint256 tokenId, bool transferable) public onlyAdmin
    {
        transferables[tokenId] = transferable ? 1 : 2;
    }

    function getTransferables(uint256 tokenId) public view returns (bool)
    {
        return transferables[tokenId] == 1;
    }

    // 设置某一类卡可以铸造的上限
    function setMintableAmount(uint256 tokenId, uint256 amount) public onlyAdmin
    {
        mintableAmount[tokenId] = amount;
    }

    function getMintableAmount(uint256 tokenId) public view returns(uint256)
    {
        return mintableAmount[tokenId];
    }
    // 设置某一类卡已经铸造的数量
    function getMintedAmount(uint256 tokenId) public view returns(uint256)
    {
        return mintedAmount[tokenId];
    }
    // 查询minter已经铸币的数量
    function getMinterMintedAmount(address minter, uint256 tokenId) public view returns(uint256) {
        return minterMintedAmount[minter][tokenId];
    }

    // 设置minter能够铸造的币的数量
    function setMinterMintableAmount(address minter, uint256 tokenId, uint256 amount) public onlyAdmin {
        minterMintableAmount[minter][tokenId] = amount;
    }

    function getMinterMintableAmount(address minter, uint256 tokenId) public view returns(uint256) {
        return minterMintableAmount[minter][tokenId];
    }

    // 查询一张卡是否可用
    function getIsCouponUsable(uint256 tokenId) public view returns(bool)
    {
        FpNFT.Coupon memory coupon = couponCollection[tokenId];
        return coupon.tokenId != 0 && // coupon存在
                FpNFT.getCouponDeadline(tokenId) >= block.timestamp; // 没过期
    }

    // 查询仓位限制满足情况
    function getIsValueFullfilled(uint256 tokenId, uint256 positionValue) public view returns(bool) {
        FpNFT.Coupon memory coupon = couponCollection[tokenId];
        if (coupon.limitMin != 0 && positionValue < coupon.limitMin) return false;
        if (coupon.limitMax != 0 && positionValue > coupon.limitMax) return false;
        return true;
    }

    function doMint(
        address minter,
        address to,
        uint256 tokenId,
        uint256 amount,
        uint256 data,
        bytes32 label
    )
        internal
    {
        require(mintedAmount[tokenId] + amount <= mintableAmount[tokenId], "can't mint more for this type");
        if (minterMintableAmount[minter][tokenId] != 0) {
            require(minterMintedAmount[minter][tokenId] + amount <= minterMintableAmount[minter][tokenId], "minter cant mint more for this type");
        }

        uint8 couponFunc = FpNFT.getCouponFunc(tokenId);
        if (couponFunc == FpNFT.CouponFunc_Fee) require(data <= 1e6, "fee coupon should less than 1e6");
        if (couponFunc == FpNFT.CouponFunc_TradeMining) require(data <= 1e7, "fee coupon should less than 1e7");

        mintedAmount[tokenId] = mintedAmount[tokenId] + amount;
        minterMintedAmount[minter][tokenId] = minterMintedAmount[minter][tokenId] + amount;

        FpERC1155(fpErc1155Addr).mint(to, tokenId, amount, abi.encodePacked(data));

        if (couponCollection[tokenId].tokenId == 0) { // 如果此类卡没有记录下信息,
            FpNFT.Coupon memory coupon = FpNFT.Coupon(
                tokenId,
                data,
                usableMinValue[tokenId],
                usableMaxValue[tokenId],
                label,
                transferables[tokenId] != 2 ? true : false
            );

            couponCollection[tokenId] = coupon;
        }
    }

    function batchMint(
        address from,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        uint256[] memory dataes,
        bytes32[] memory labels,
        bytes32 minthash
    )
        public
        onlyAllowedRoles
    {
        require(MintOperationRecords[minthash] == false, "mint operation hash duplicated");
        require(
            tokenIds.length == amounts.length && tokenIds.length == dataes.length && tokenIds.length == labels.length,
            "length of infos not match"
        );

        for (uint i = 0; i < tokenIds.length; ++i) {
            doMint(from, to, tokenIds[i], amounts[i], dataes[i], labels[i]);
        }

        MintOperationRecords[minthash] = true;

        emit CouponBatchMinted(
            from,
            to,
            tokenIds,
            amounts,
            dataes,
            labels,
            minthash
        );
    }
    // 从from发券给to,
    // from可能与msg.sender不同
    function mint(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        uint256 data,
        bytes32 label,
        bytes32 minthash
    )
        public
        onlyAllowedRoles
    {
        require(MintOperationRecords[minthash] == false, "mint operation hash duplicated");

        doMint(from, to, tokenId, amount, data, label);

        MintOperationRecords[minthash] = true;

        emit CouponMinted(
            from,
            to,
            tokenId,
            amount,
            data,
            label,
            minthash
        );
    }

    // 使用掉一张卡, 返回对应的信息
    // 1. 如果是手续费减免卡, 则condition表示输入的手续费, 返回打折后的手续费.
    // 2. 如果是挖矿翻倍卡, 则condition表示输入的成交量, 返回翻倍后的成交量.
    function useCoupon(address owner, uint256 tokenId, uint256 amount, uint256 condition)
        public
        onlyFP
        returns(uint256)
    {
        do {
            if (amount == 0) break;

            FpERC1155 fp1155 = FpERC1155(fpErc1155Addr);
            if (fp1155.balanceOf(owner, tokenId) < amount) break;

            if (!getIsCouponUsable(tokenId)) break;

            FpNFT.Coupon memory coupon = couponCollection[tokenId];
            uint8 couponFunc = FpNFT.getCouponFunc(tokenId);

            if (
                couponFunc == FpNFT.CouponFunc_Fee ||
                couponFunc == FpNFT.CouponFunc_TradeMining
            )
            {
                for (uint256 i = 0; i < amount; ++i) {
                    condition = condition.pmul(coupon.data);
                }

                fp1155.burn(owner, tokenId, amount);
                emit CouponUsed(owner, tokenId, amount);
            }
        } while(false);
        return condition;
    }
    // 转让
    function transferCoupon(address owner, address to, uint256 tokenId, uint256 amount) public {
        require(owner == msg.sender || futurePerpetualAddr == msg.sender, "not authorized to transfer");
        require(couponCollection[tokenId].transferable, "not transferable coupon");

        FpERC1155 fp1155 = FpERC1155(fpErc1155Addr);
        uint256 balance = fp1155.balanceOf(owner, tokenId);
        require(balance >= amount, "do not have enough coupon to transfer");

        fp1155.transfer(owner, to, tokenId, amount);

        emit CouponTransfered(msg.sender, owner, to, tokenId, amount);
    }

    // 给view方法使用的, 检查一下如果使用coupon, 能得到怎样的结果
    function checkCoupons(uint256[] memory coupons, uint256 condition, uint8 couponFunc)
        public
        view
        returns(uint256)
    {
        for (uint i= 0; i < coupons.length; i = i + 2) {
            uint256 tokenId = coupons[i];
            FpNFT.Coupon memory coupon = couponCollection[tokenId];
            uint8 func = FpNFT.getCouponFunc(tokenId);

            if (func == couponFunc)
            {
                uint256 amount = coupons[i + 1];
                for (uint256 j = 0; j < amount; ++j) {
                    condition = condition.pmul(coupon.data);
                }

            }
        }
        return condition;
    }

    function setMaxLuckyBoxRanges(uint8 ranges) public onlyAdmin {
        maxLuckyBoxRanges = ranges;
    }
    // 设置打开盲盒时铸币的参数,
    function setLuckyBoxMetaData(uint256 boxId, uint8 index, FpNFT.LuckyBoxMetaData memory params) public onlyAdmin {
        require(index < maxLuckyBoxRanges, "overpass lucky box ranges");

        // params.mintedCount = 0;
        luckyBoxMetaData[boxId][index] = params;
    }

    function getLuckyBoxMetaData(uint256 boxId, uint8 index) public view returns(FpNFT.LuckyBoxMetaData memory) {
        return luckyBoxMetaData[boxId][index];
    }

    // 设置coupon合成时的参数
    function setCombinedMetaData(uint256 target, FpNFT.CombinedMetaData[] memory metas) public onlyAdmin {
        delete combinedMetaData[target];
        for (uint i = 0; i < metas.length; i++) {
            combinedMetaData[target].push(metas[i]);
        }
    }

    // 转让盲盒
    function transferLuckyBox(address to, uint256[] memory boxIds, uint256[] memory boxAmounts) public onlyEOA {
        require(to != msg.sender, "can not transfer to self");
        require(to != address(0), "can not transfer to address(0)");
        require(boxIds.length > 0 && boxIds.length == boxAmounts.length, "params wrong");

        FpERC1155 fp1155 = FpERC1155(fpErc1155Addr);
        for (uint i = 0; i < boxIds.length; i++) {
            fp1155.transfer(msg.sender, to, boxIds[i], boxAmounts[i]);
            emit CouponTransfered(msg.sender, msg.sender, to, boxIds[i], boxAmounts[i]);
        }
        emit LuckyBoxTransfered(msg.sender, to, boxIds, boxAmounts);
    }

    // 铸造盲盒
    function mintLuckyBox(address to, uint256 boxId, uint8 reason)
        public
        onlyAllowedRoles
    {
        doMint(msg.sender, to, boxId, 1, 0, bytes32("luckybox"));

        emit LuckyBoxMinted(to, boxId, reason);
    }
    // 打开盲盒
    function openLuckyBox(uint256 boxId) public onlyEOA {
        FpERC1155 fp1155 = FpERC1155(fpErc1155Addr);
        uint256 balance = fp1155.balanceOf(msg.sender, boxId);
        require(balance >= 1, "no box holded");

        uint256 deadline = FpNFT.getCouponDeadline(boxId);
        require(deadline <= block.timestamp, "box is expired");

        uint8 boxType = FpNFT.getCouponType(boxId);
        require(boxType == FpNFT.CouponType_LuckyBox, "not luckybox");

        uint256 luckyNum = genRandomNumber(boxId);

        (uint256 tokenId, uint256 data, bytes32 label) = getParamsByOpenLuckyBox(boxId, uint8(luckyNum % 100));

        // 设置开盲盒时, 数量不占用原设置
        mintableAmount[tokenId] += 1;
        if (minterMintableAmount[msg.sender][tokenId] != 0) minterMintableAmount[msg.sender][tokenId] += 1;

        doMint(msg.sender, msg.sender, tokenId, 1, data, label);

        fp1155.burn(msg.sender, boxId, 1);

        emit LuckyBoxOpened(msg.sender, boxId, tokenId);
    }

    function genRandomNumber(uint256 seed) internal view returns(uint256) {
        return uint256(keccak256(abi.encode(
            msg.sender,
            block.timestamp,
            block.number,
            seed
        )));
    }

    function doCompositCouponParams(uint256 boxId, uint8 index)
        internal
        returns(uint256 tokenId, uint256 data, bytes32 label)
    {
        luckyBoxMetaData[boxId][index].mintedCount += 1;

        tokenId = luckyBoxMetaData[boxId][index].tokenId;
        data    = luckyBoxMetaData[boxId][index].data;
        label = luckyBoxMetaData[boxId][index].label;
    }

    function getParamsByOpenLuckyBox(
        uint256 boxId,
        uint8 luckyNum
    )
        internal
        returns(
        uint256 tokenId, uint256 data, bytes32 label
    ) {
        // 只支持普通盲盒或稀有盲盒
        uint8 boxFunc = FpNFT.getCouponFunc(boxId);
        require(
            boxFunc == FpNFT.CouponFunc_LuckyBox_Common
            || boxFunc == FpNFT.CouponFunc_LuckyBox_Scarce,
            "not support box func"
        );

        for (uint8 i = 0; i < maxLuckyBoxRanges; i++) { // 默认随机数分为十级
            FpNFT.LuckyBoxMetaData memory meta = luckyBoxMetaData[boxId][i];

            if (meta.rangeStart == 0 && meta.rangeEnd == 0) {
                require(false, "lucky box metadata setting error"); // 出了随机数范围, 参数设置出错了
            }

            if (luckyNum >= meta.rangeStart && luckyNum < meta.rangeEnd) { // 命中随机数范围
                if (meta.mintedCount < meta.maxCount) { // 允许铸造
                    return doCompositCouponParams(boxId, i);
                } else { // 已经超出了铸造数量, 随便找一个可以铸造的
                    break;
                }
            }
        }

        // 找可以铸的铸造
        for (uint8 i = 0; i < maxLuckyBoxRanges; i++) { // 默认随机数分为十级
            FpNFT.LuckyBoxMetaData memory meta = luckyBoxMetaData[boxId][i];
            if (meta.mintedCount < meta.maxCount) {
                return doCompositCouponParams(boxId, i);
            }
        }

        require(false, "can not mint more coupon by luckybox");
    }

    // Coupon合成
    function mint721Card(uint256 target, address to) internal returns(uint256) {
        FpERC721 fp721 = FpERC721(fpErc721Addr);

        uint256 mintedCount = fp721.countOf(target);
        uint256 id = target + mintedCount;

        fp721.mintByFpCoupon(target, to, id);

        return id;
    }

    function combineCoupon(uint256 target, uint256[] memory couponIds) public onlyEOA {
        FpNFT.CombinedMetaData[] memory metas = combinedMetaData[target];
        require(metas.length > 0, "target not support");

        FpNFT.CombinedMetaData[] memory matchPair = new FpNFT.CombinedMetaData[](FpNFT.CouponFunc_Total);

        // 统计传入的参数中, 各功能类型卡的数量
        FpERC1155 fp1155 = FpERC1155(fpErc1155Addr);
        for (uint i = 0; i < couponIds.length; i++) {
            require(fp1155.balanceOf(msg.sender, couponIds[i]) >= 1, "do not have enough coupon");
            uint8 func = FpNFT.getCouponFunc(couponIds[i]);
            uint8 identity = FpNFT.getCouponIdentity(couponIds[i]);

            matchPair[func].func = func;
            matchPair[func].identity = identity;
            matchPair[func].amount += 1;
        }

        // 检查是否满足要求
        uint8 diffAmount;
        for (uint i = 0; i < metas.length; i++) {
            uint8 index = metas[i].func;
            if (matchPair[index].identity == metas[i].identity) {
                if (metas[i].amount > matchPair[index].amount) {
                    diffAmount += (metas[i].amount - matchPair[index].amount);
                }
            } else {
                diffAmount += metas[i].amount;
            }
        }

        require(matchPair[FpNFT.CouponFunc_Universal].amount >= diffAmount, "combine coupon failed: amount not enough");

        // 铸造721卡
        uint256 cardId = mint721Card(target, msg.sender);

        // 销毁Coupon
        for (uint i = 0; i < couponIds.length; i++) {
            fp1155.burn(msg.sender, couponIds[i], 1);
        }

        emit CouponCombined(msg.sender, target, couponIds, cardId);
    }
}
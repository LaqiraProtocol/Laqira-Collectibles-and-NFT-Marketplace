const { expect } = require("chai");
const {ethers, upgrades, waffle} = require("hardhat");
const { constants } = require('@openzeppelin/test-helpers');
const provider = waffle.provider;

describe('ExchangeNFTs', function () {
    let owner, seller, buyer, anotherAddress, anotherAddress2, bidder1, bidder2, bidder3, feeAddress, exchangeContract, configContract,
    ExchangeContract, ConfigContract, token, TokenContract, quoteToken, QuoteTokenContract, QuoteTokenContract2, royalties,
    RoyaltiesContract, defaultSettings, values;
    beforeEach(async function () {
        const tokenName = 'LaqiraNFT';
        const tokenSymbol = 'LQRN';
        [owner, seller, buyer, anotherAddress, anotherAddress2, receiver, feeAddress, bidder1, bidder2, bidder3] = await ethers.getSigners();

        token =  await ethers.getContractFactory("LaqiraNFT");
        configContract = await ethers.getContractFactory("ExchangeNFTConfiguration");
        exchangeContract = await ethers.getContractFactory("ExchangeNFTs");
        quoteToken = await ethers.getContractFactory("QuoteToken");
        royalties = await ethers.getContractFactory("RoyaltiesProvider")

        ConfigContract = await upgrades.deployProxy(configContract, {kind: 'transparent'});
        ExchangeContract = await upgrades.deployProxy(exchangeContract, [ConfigContract.address], {kind: 'transparent'});
        RoyaltiesContract = await upgrades.deployProxy(royalties, ['10000'], {kind: 'transparent'});
        TokenContract = await upgrades.deployProxy(token, [tokenName, tokenSymbol, feeAddress.address, '0', RoyaltiesContract.address], {kind: 'transparent'});
        QuoteTokenContract = await quoteToken.deploy('Quote', 'QT', '10000000000000000000000000000');
        QuoteTokenContract2 = await quoteToken.deploy('Quote2', 'QT2', '10000000000000000000000000000');

        await TokenContract.setRoyaltiesProviderAddress(RoyaltiesContract.address);
        await RoyaltiesContract.setAllowedNFT(TokenContract.address);

        values = {nft: TokenContract.address, quotes: [QuoteTokenContract.address], feeAddresses: [feeAddress.address], 
        feeValues: [0], feeBurnAbles: [false], royaltiesProviders: [constants.ZERO_ADDRESS], royaltiesBurnables: [false] };
        defaultSettings = await defaultValues(values, false);
    });

    describe('config', function () {
        it('config address', async function () {
            expect(await ExchangeContract.config()).to.equal(ConfigContract.address);
        });

        it('checkEnableTrade', async function () {
            await expect(ConfigContract.checkEnableTrade(TokenContract.address, QuoteTokenContract.address)).to.be.revertedWith('nft disable');
            await setup(ConfigContract, 'enable', {nft: TokenContract.address, status: true});
            await expect(ConfigContract.checkEnableTrade(TokenContract.address, QuoteTokenContract.address)).to.be.revertedWith('quote disable');
            await setup(ConfigContract, 'enableQuote', {nft: TokenContract.address, quotes: [QuoteTokenContract.address], status: true});
            await expect(ConfigContract.checkEnableTrade(TokenContract.address, QuoteTokenContract.address)).to.be.not.reverted;
        });

        it('getNftQuotes', async function () {
            expect((await ExchangeContract.getNftQuotes(TokenContract.address)).length).to.equal(0);
            await setup(ConfigContract, 'enableQuote', {nft: TokenContract.address, quotes: [QuoteTokenContract.address, QuoteTokenContract2.address] , status: true});
            expect((await ExchangeContract.getNftQuotes(TokenContract.address))[0]).to.equal(QuoteTokenContract.address);
            expect((await ExchangeContract.getNftQuotes(TokenContract.address))[1]).to.equal(QuoteTokenContract2.address);
        });

        it('addNFT & nftSettings', async function () {
            await setup(ConfigContract, 'add', defaultSettings);
            const result = await ConfigContract.nftSettings(TokenContract.address, QuoteTokenContract.address);
            expect(result.enable).to.be.true;
            expect(result.nftQuoteEnable).to.be.true;
            expect(result.feeAddress).to.equal(feeAddress.address);
            expect(result.feeBurnAble).to.be.false;;
            expect(result.feeValue).to.equal('0');
            expect(result.royaltiesProvider).to.equal(constants.ZERO_ADDRESS);
            expect(result.royaltiesBurnable).to.be.false;
        });

        it('get royalties', async function () {
            const data = {nft: TokenContract.address, status: true, quotes: [QuoteTokenContract.address], feeAddresses: [feeAddress.address], 
            feeValues: [0], feeBurnAbles: [false], royaltiesProviders: [RoyaltiesContract.address], royaltiesBurnables: [false] };
               
            await setup(ConfigContract, 'add', data);
            expect(await ConfigContract.royaltiesProviders(TokenContract.address, QuoteTokenContract.address)).to.equal(RoyaltiesContract.address);
        });
    });

    describe('royalties', function () {
        const tokenId = 1;
        const price = '10000000000000000000';
        it('transfer fee', async function () {
            const data = {nft: TokenContract.address, status: true, quotes: [QuoteTokenContract.address], feeAddresses: [feeAddress.address], 
            feeValues: [250], feeBurnAbles: [false], royaltiesProviders: [RoyaltiesContract.address], royaltiesBurnables: [false] };
            
            await setup(ConfigContract, 'add', data);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(TokenContract.address, tokenId, QuoteTokenContract.address, price, seller.address, '0');
            
            await QuoteTokenContract.transfer(buyer.address, price);
            await QuoteTokenContract.connect(buyer).approve(ExchangeContract.address, price);
            
            await ExchangeContract.connect(buyer).buyToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price);
            
            expect(await QuoteTokenContract.balanceOf(buyer.address)).to.equal('0');
            expect(await QuoteTokenContract.balanceOf(feeAddress.address)).to.equal(((price * 250) / 10000).toString());
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal((price - (price * 250) / 10000).toString());
        });

        it('fee array', async function () {
            const data = {nft: TokenContract.address, status: true, quotes: [QuoteTokenContract.address], feeAddresses: [feeAddress.address], 
            feeValues: [250], feeBurnAbles: [false], royaltiesProviders: [RoyaltiesContract.address], royaltiesBurnables: [false] };
            
            await setup(ConfigContract, 'add', data);
            await TokenContract.connect(seller).mint('123456', [anotherAddress.address, anotherAddress2.address], ['2000', '3000']);
            await TokenContract.confirmNFT(tokenId);
            
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(TokenContract.address, tokenId, QuoteTokenContract.address, price, seller.address, '0');
            
            await QuoteTokenContract.transfer(buyer.address, price);
            await QuoteTokenContract.connect(buyer).approve(ExchangeContract.address, price);
            await ExchangeContract.connect(buyer).buyToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price);

            expect(await QuoteTokenContract.balanceOf(feeAddress.address)).to.equal((price * 250 / 10000).toString());
            const price1 = price - (price * 250 / 10000);
            expect(await QuoteTokenContract.balanceOf(anotherAddress.address)).to.equal((price * 2000 / 10000).toString());
            const price2 = price1 - (price * 2000 / 10000);
            expect(await QuoteTokenContract.balanceOf(anotherAddress2.address)).to.equal((price * 3000 / 10000).toString());
            const price3 = price2 - (price * 3000 / 10000);
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal(price3.toString());
        });
    });

    describe('readyToSellToken', function () {
        const tokenId = '1';
        const price = '1000000000000000000000000000';
        it('readyToSellTokenTo & buyToken', async function () {
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, owner);
            await TokenContract.approve(ExchangeContract.address, tokenId);
            await ExchangeContract.readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, owner.address, '0');
            expect(await TokenContract.ownerOf(tokenId)).to.equal(ExchangeContract.address);
            
            const userAsks = await ExchangeContract.getUserAsks(TokenContract.address, QuoteTokenContract.address, owner.address);
            expect(userAsks[0]['price']).to.equal(price);
            expect(userAsks[0]['tokenId']).to.equal(tokenId);

            await mintNFT(TokenContract, '2', seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, '2');
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], '2', defaultSettings['quotes'][0], price, seller.address, '0');
            const getAsks = await ExchangeContract.getAsks(TokenContract.address, QuoteTokenContract.address);
            
            expect(getAsks[0]['price']).to.equal(price);
            expect(getAsks[0]['tokenId']).to.equal(tokenId);
            expect(getAsks[1]['price']).to.equal(price);
            expect(getAsks[1]['tokenId']).to.equal('2');
            
            // Buy Token
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal('0');
            await QuoteTokenContract.connect(owner).transfer(buyer.address, price);
            await QuoteTokenContract.connect(buyer).approve(ExchangeContract.address, price);
            await ExchangeContract.connect(buyer).buyToken(defaultSettings['nft'], '2', defaultSettings['quotes'][0], price);
            expect(await TokenContract.ownerOf('2')).to.equal(buyer.address);
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal(price);
        });

        it('cancelSellToken', async function () {
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, seller.address, '0');
            
            expect(await TokenContract.ownerOf(tokenId)).to.equal(ExchangeContract.address);
            
            const userAsks = await ExchangeContract.getUserAsks(TokenContract.address, QuoteTokenContract.address, seller.address);
            expect(userAsks.length).to.equal(1);
            expect(userAsks[0]['price']).to.equal(price);
            expect(userAsks[0]['tokenId']).to.equal(tokenId);

            await ExchangeContract.connect(seller).cancelSellToken(TokenContract.address, tokenId);
            const UserAsks2 = await ExchangeContract.getUserAsks(TokenContract.address, QuoteTokenContract.address, seller.address);
            expect(UserAsks2.length).to.equal(0);
            expect(await TokenContract.ownerOf(tokenId)).to.equal(seller.address);
        });
    });

    describe('bidToken', function () {
        const onlyBid = '1';
        const tokenId = '1';
        const price = '1000000000000000000000000000';

        // bids
        const bid1_Price = '1000000000000000000000';
        const bid2_Price = '10000000000000000000';
        const bid3_Price = '56200000000000000000';
        it('bidToken', async function () {
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, seller.address, onlyBid);
            
            await QuoteTokenContract.connect(owner).transfer(buyer.address, price);
            await QuoteTokenContract.connect(buyer).approve(ExchangeContract.address, price);
            await expect(ExchangeContract.connect(buyer).buyToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price)).to.be.revertedWith('only bid');
            
            // Transfer section
            await QuoteTokenContract.transfer(bidder1.address, bid1_Price);
            await QuoteTokenContract.transfer(bidder2.address, bid2_Price);
            await QuoteTokenContract.transfer(bidder3.address, bid3_Price);
            
            await QuoteTokenContract.connect(bidder1).approve(ExchangeContract.address, bid1_Price);
            await QuoteTokenContract.connect(bidder2).approve(ExchangeContract.address, bid2_Price);
            await QuoteTokenContract.connect(bidder3).approve(ExchangeContract.address, bid3_Price);

            await ExchangeContract.connect(bidder1).bidToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid1_Price);
            await ExchangeContract.connect(bidder2).bidToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid2_Price);
            await ExchangeContract.connect(bidder3).bidToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid3_Price);
            expect(await TokenContract.ownerOf(tokenId)).to.equal(ExchangeContract.address);

            expect(await ExchangeContract.getBidsLength(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId)).to.equal('3');
            const bids = await ExchangeContract.getBids(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId);

            expect(bids[0]['bidder']).to.equal(bidder1.address);
            expect(bids[1]['bidder']).to.equal(bidder2.address);
            expect(bids[2]['bidder']).to.equal(bidder3.address);

            expect(bids[0]['price']).to.equal(bid1_Price);
            expect(bids[1]['price']).to.equal(bid2_Price);
            expect(bids[2]['price']).to.equal(bid3_Price);

            await ExchangeContract.connect(seller).sellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid1_Price, bidder1.address);
            
            expect(await TokenContract.ownerOf(tokenId)).to.equal(bidder1.address);
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal(bid1_Price);
            expect(await ExchangeContract.getBidsLength(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId)).to.equal('2');

            const updatedBids = await ExchangeContract.getBids(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId);
            
            expect(updatedBids[0]['bidder']).to.equal(bidder2.address);
            expect(updatedBids[1]['bidder']).to.equal(bidder3.address);
            
            expect(updatedBids[0]['price']).to.equal(bid2_Price);
            expect(updatedBids[1]['price']).to.equal(bid3_Price);

            // cancel bid -> user 1
            expect(await QuoteTokenContract.balanceOf(bidder2.address)).to.equal(0);
            await ExchangeContract.connect(bidder2).cancelBidToken(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId);
            expect(await QuoteTokenContract.balanceOf(bidder2.address)).to.equal(bid2_Price);
            expect(await ExchangeContract.getBidsLength(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId)).to.equal('1');
            
            // cancel bid -> user 2
            expect(await QuoteTokenContract.balanceOf(bidder3.address)).to.equal(0);
            await ExchangeContract.connect(bidder3).cancelBidToken(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId);
            expect(await QuoteTokenContract.balanceOf(bidder3.address)).to.equal(bid3_Price);
            expect(await ExchangeContract.getBidsLength(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId)).to.equal(0);
        });

        it('updateBidPrice', async function () {
            const updatedBidPrice = '999999999999999';
            const invalidPrice = '0';
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, seller.address, onlyBid);
            
            // Transfer section
            await QuoteTokenContract.transfer(bidder1.address, bid1_Price);
            
            await QuoteTokenContract.connect(bidder1).approve(ExchangeContract.address, bid1_Price);
            
            await ExchangeContract.connect(bidder1).bidToken(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid1_Price);

            expect(await ExchangeContract.getBidsLength(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId)).to.equal('1');
            const bids = await ExchangeContract.getBids(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId);
            expect(bids[0]['price']).to.equal(bid1_Price);

            await expect(ExchangeContract.connect(anotherAddress).updateBidPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], updatedBidPrice)).to.be.revertedWith('Only Bidder can update the bid price');
            await expect(ExchangeContract.connect(bidder1).updateBidPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], invalidPrice)).to.be.revertedWith('Price must be greater than zero');
            await expect(ExchangeContract.connect(bidder1).updateBidPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid1_Price)).to.be.revertedWith('The bid price cannot be the same');
            
            await ExchangeContract.connect(bidder1).updateBidPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], updatedBidPrice);
            const updateBid = await ExchangeContract.getBids(defaultSettings['nft'], defaultSettings['quotes'][0], tokenId);
            expect(updateBid[0]['price']).to.equal(updatedBidPrice);
        });

        it('bidTokenTo', async function () {
            const nftReceiver = anotherAddress.address;
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, seller.address, onlyBid);

            await QuoteTokenContract.connect(owner).transfer(bidder1.address, bid1_Price);
            await QuoteTokenContract.connect(bidder1).approve(ExchangeContract.address, bid1_Price);
            await ExchangeContract.connect(bidder1).bidTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid1_Price, nftReceiver);
            
            await ExchangeContract.connect(seller).sellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], bid1_Price, nftReceiver);
            expect(await TokenContract.ownerOf(tokenId)).to.equal(nftReceiver);
            expect(await QuoteTokenContract.balanceOf(nftReceiver)).to.equal('0');
            expect(await QuoteTokenContract.balanceOf(bidder1.address)).to.equal('0');
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal(bid1_Price);
        });
    });
    describe('UpdatePrice', function () {
        const tokenId = '1';
        const price = '1000000000000000000000000000';
        const updatePrice = '100000000000';
        const invalidPrice = '0';
        const bidAndBuy = '0';
        it('UpdatePrice', async function () {
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, seller.address, bidAndBuy); 
            
            const userAsks = await ExchangeContract.getUserAsks(defaultSettings['nft'], defaultSettings['quotes'][0], seller.address);
            expect(userAsks[0]['price']).to.equal(price);
            
            await expect(ExchangeContract.connect(owner).setCurrentPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], updatePrice)).to.be.revertedWith('Only Seller can update price');
            await expect(ExchangeContract.connect(seller).setCurrentPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], invalidPrice)).to.be.revertedWith('Price must be greater than zero');

            await ExchangeContract.connect(seller).setCurrentPrice(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], updatePrice);
            const updatedAsk = await ExchangeContract.getUserAsks(defaultSettings['nft'], defaultSettings['quotes'][0], seller.address)
            expect(updatedAsk[0]['price']).to.equal(updatePrice);            
        });
    });

    describe('buyTokenTo', function () {
        const tokenId = '1';
        const price = '1000000000000000000000000000';
        it('Gift token', async function () {
            const nftReceiver = anotherAddress.address;
            await setup(ConfigContract, 'add', defaultSettings);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
            await ExchangeContract.connect(seller).readyToSellTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, seller.address, '0');
            
            await QuoteTokenContract.transfer(buyer.address, price);
            await QuoteTokenContract.connect(buyer).approve(ExchangeContract.address, price);
            await ExchangeContract.connect(buyer).buyTokenTo(defaultSettings['nft'], tokenId, defaultSettings['quotes'][0], price, nftReceiver);
            
            expect(await TokenContract.ownerOf(tokenId)).to.equal(nftReceiver);
            expect(await QuoteTokenContract.balanceOf(nftReceiver)).to.equal('0');
            expect(await QuoteTokenContract.balanceOf(seller.address)).to.equal(price);
        });
    }); 

    // payable functions
    describe('(payable)', function () {
        const QUOTETOKEN_ADDRESS = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
        const tokenId = '1';
        const price = ethers.BigNumber.from('1000000000000000');
        const invalidPrice = ethers.BigNumber.from('10000000000000');
        let nft_address;
        beforeEach(async function () {
            nft_address = TokenContract.address
            await setup(ConfigContract, 'add', defaultSettings, true);
            nftSettings = await ConfigContract.nftSettings(nft_address, QUOTETOKEN_ADDRESS);
            await mintNFT(TokenContract, tokenId, seller);
            await TokenContract.connect(seller).approve(ExchangeContract.address, tokenId);
        });

        it('readyToSellToken(payable)', async function () {
            await ExchangeContract.connect(seller).readyToSellTokenTo(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, seller.address, '0');

            await expect(ExchangeContract.connect(buyer).buyToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price)).to.be.revertedWith('error msg value');
            await expect(ExchangeContract.connect(buyer).buyToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, {value: invalidPrice})).to.be.revertedWith('error msg value');
            
            const balanceBeforeTransfer = ethers.BigNumber.from(await provider.getBalance(seller.address));

            await ExchangeContract.connect(buyer).buyToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, {value: price});
            
            const balanceAfterTransfer = ethers.BigNumber.from(await provider.getBalance(seller.address));
            
            expect(balanceAfterTransfer).to.equal(balanceBeforeTransfer.add(price));
        });

        it('bidToken', async function () {
            const unavailableTokenId = '10';
            await ExchangeContract.connect(seller).readyToSellTokenTo(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, seller.address, '1');
            
            await expect(ExchangeContract.connect(bidder1).bidToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, {value: price.sub('1')})).to.be.revertedWith('error msg value');
            await expect(ExchangeContract.connect(seller).bidToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, {value: price})).to.be.revertedWith('Owner cannot bid');
            await expect(ExchangeContract.connect(bidder1).bidToken(nft_address, unavailableTokenId, QUOTETOKEN_ADDRESS, price, {value: price})).to.be.revertedWith('Token not in sell book');
            
            await ExchangeContract.connect(bidder1).bidToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, {value: price});   
            
            await expect(ExchangeContract.connect(bidder1).bidToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price, {value: price})).to.be.revertedWith('Bidder already exists');   
            
            const contractBalance = ethers.BigNumber.from(await provider.getBalance(ExchangeContract.address));
            expect(contractBalance).to.equal(price);

            await ExchangeContract.connect(bidder2).bidToken(nft_address, tokenId, QUOTETOKEN_ADDRESS, price.mul('2'), {value: price.mul('2')});
            
            expect(ethers.BigNumber.from(await provider.getBalance(ExchangeContract.address))).to.equal(price.add(price.mul('2')));
            
            const mainBalance = ethers.BigNumber.from(await provider.getBalance(ExchangeContract.address));

            await ExchangeContract.connect(bidder1).cancelBidToken(nft_address, QUOTETOKEN_ADDRESS, tokenId);

            const updatedBalance = ethers.BigNumber.from(await provider.getBalance(ExchangeContract.address));
            expect(updatedBalance).to.equal(mainBalance.sub(price));
            await ExchangeContract.connect(bidder2).cancelBidToken(nft_address, QUOTETOKEN_ADDRESS, tokenId);
            expect(await provider.getBalance(ExchangeContract.address)).to.equal(0);
        });
    });
});

// helpers
async function setup(contract, key, data, payable=false) {
    if (payable) {
        data = await defaultValues(data, true);
    }
    switch (key) {
        case 'enable' :
            await contract.setNftEnables(data['nft'], data['status']);
            break;
        case 'enableQuote':
            await contract.setNftQuoteEnables(data['nft'], data['quotes'], data['status']);
            break;
        case 'add':
            await contract.addNft(data['nft'], data['status'], data['quotes'],
            data['feeAddresses'], data['feeValues'], data['feeBurnAbles'],
            data['royaltiesProviders'], data['royaltiesBurnables']);
            break;
        default:
            console.log('Invalid key');
            break;
    }
}

async function defaultValues(data, payable=false) {
    if (!payable) {
        return {
            nft: data['nft'],
            status: true,
            quotes: data['quotes'],
            feeAddresses: data['feeAddresses'],
            feeValues: data['feeValues'],
            feeBurnAbles: data['feeBurnAbles'],
            royaltiesProviders: data['royaltiesProviders'],
            royaltiesBurnables: data['royaltiesBurnables']
        }
    } else {
        return {
            // ETH address
            nft: data['nft'],
            status: true,
            quotes: ['0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'],
            feeAddresses: data['feeAddresses'],
            feeValues: data['feeValues'],
            feeBurnAbles: data['feeBurnAbles'],
            royaltiesProviders: data['royaltiesProviders'],
            royaltiesBurnables: data['royaltiesBurnables']
        }
    }
}

async function mintNFT(contract, tokenId, minter) {
    await contract.connect(minter).mint('123456', [minter.address], ['0']);
    await contract.confirmNFT(tokenId);
}
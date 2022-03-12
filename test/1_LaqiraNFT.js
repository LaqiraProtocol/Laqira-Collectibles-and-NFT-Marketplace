const { expect } = require("chai");
const {ethers, upgrades, waffle} = require("hardhat");
const web3 = require('web3')
const {constants} = require('@openzeppelin/test-helpers');
const provider = waffle.provider;

var chai = require('chai');
var BN = require('bn.js');
var bnChai = require('bn-chai');
chai.use(bnChai(BN));

describe("LaqiraNFT", function () {
    let owner, feeAddress, token, user1, user2, tokenContract, royalties, royaltiesContract, mintingFee, tokenURI, totalRoyalties, invalidNFT;
    const name = 'LaqiraNFT';
    const symbol = 'LQRN';
    tokenURI = '12345';
    totalRoyalties = '50';

    beforeEach(async function () {
        [owner, feeAddress, user1, user2, anotherAddress] = await ethers.getSigners();
        mintingFee = '10000000000000000';

        token = await ethers.getContractFactory("LaqiraNFT");
        royalties = await ethers.getContractFactory("RoyaltiesProvider");

        royaltiesContract = await upgrades.deployProxy(royalties, [totalRoyalties], {kind: 'transparent'});
        tokenContract = await upgrades.deployProxy(token, [name, symbol, feeAddress.address, mintingFee, royaltiesContract.address], {kind: 'transparent'});
        invalidNFT = await upgrades.deployProxy(token, [name, symbol, feeAddress.address, mintingFee, royaltiesContract.address], {kind: 'transparent'});
        
        // setup
        await royaltiesContract.setAllowedNFT(tokenContract.address);
    });

    describe('ownership', function () {
        it('check owner', async function () {
            expect(await tokenContract.owner()).to.equal(owner.address);
        });
    });

    describe('mint', function () {
        it('getPendingRequests', async function () {
            const feeAddressBalance = ethers.BigNumber.from(await provider.getBalance(feeAddress.address)) / 10 ** 16;
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            expect(await tokenContract.getPendingRequests()).to.eq.BN('1');
            expect(ethers.BigNumber.from((await provider.getBalance(feeAddress.address)) / 10 ** 16)).to.equal(parseInt(feeAddressBalance) + (parseInt(mintingFee) / 10 ** 16));
        });

        it('totalSupply', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            expect(await tokenContract.totalSupply()).to.equal('0');
        });

        it('pendingDetails', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            const result = await tokenContract.fetchPendingIdDetails('1');
            expect(result['owner']).to.equal(user1.address);
            expect(result['tokenURI']).to.equal(tokenURI);
        });

        it('userPendingRequests', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            const values = await tokenContract.getUserPendingIds(user1.address);
            expect(values[0]).to.equal('1');
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            const values2 = await tokenContract.getUserPendingIds(user1.address);
            expect(values2[1]).to.equal('2');
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            const values3 = await tokenContract.getUserPendingIds(user1.address);
            expect(values3[2]).to.equal('3');
        });

        it('should revert', async function () {
            await expect(tokenContract.connect(user1).mint(tokenURI, [constants.ZERO_ADDRESS], ['0'], {value: mintingFee})).to.be.revertedWith('Zero address cannot be royaltyOwner');
        });

        it('total royalties', async function () {
            await expect(tokenContract.connect(user1).mint(tokenURI, [user2.address, anotherAddress.address], ['31', '20'], {value: mintingFee})).to.be.revertedWith('Invalid total royaltie');
        });

        it('Only allowed NFT', async function () {
            await expect(invalidNFT.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee})).to.be.revertedWith('Only allowedNFT');
        });

        it('Invalid royalties length', async function () {
            await expect(tokenContract.connect(user1).mint(tokenURI, [user2.address], ['10', '10'], {value: mintingFee})).to.be.revertedWith('Invalid length');
        });

        it('Insufficient paid amount ', async function () {
            await expect(tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: '10000'})).to.be.revertedWith('Insufficient paid amount');
        });
    });

    describe('confirmNFT', function () {
        const tokenId = '1';
        it('only operator or owner', async function () {
            await tokenContract.setAsOperator(user1.address);
            expect(await tokenContract.isOperator(user1.address)).to.be.true;

            await tokenContract.connect(user2).mint(tokenURI, [user2.address], ['0'], {value: mintingFee});
            await expect(tokenContract.connect(user2).confirmNFT('1')).to.revertedWith('Permission denied!');

            await expect(tokenContract.connect(user1).confirmNFT('1')).not.to.be.reverted;
        });

        it('Update getPendingRequests', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});

            const pendingIds = await tokenContract.getPendingRequests();
            await tokenContract.confirmNFT(tokenId);
            expect((await tokenContract.getPendingRequests()).length).to.eq.BN(pendingIds.length - 1);
            
            const userPendingIds = await tokenContract.getUserPendingIds(user1.address);
            expect(existsId(userPendingIds, tokenId)).to.be.false;

            await expect(tokenContract.confirmNFT(tokenId)).to.revertedWith('ERC721: mint to the zero address');
        });

        it('Ownership deatils and totalsupply', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            const totalSupply = await tokenContract.totalSupply();
            const userBalance = await tokenContract.balanceOf(user1.address);

            await tokenContract.confirmNFT('1');

            expect(await tokenContract.totalSupply()).to.equal(totalSupply + 1);
            expect(await tokenContract.balanceOf(user1.address)).to.equal(userBalance + 1);
            expect(await tokenContract.ownerOf('1')).to.equal(user1.address);
        });
    });

    describe('RejectNFT', function () {
        const tokenId = '1';
        it('Only operator or owner', async function () {
            await tokenContract.setAsOperator(user1.address);
            expect(await tokenContract.isOperator(user1.address)).to.be.true;

            await tokenContract.connect(user2).mint(tokenURI, [user2.address], ['0'], {value: mintingFee});
            await expect(tokenContract.connect(user2).rejectNFT('1')).to.revertedWith('Permission denied!');

            await expect(tokenContract.connect(user1).rejectNFT('1')).not.to.be.reverted;
        });
        
        it('RejectNFT', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});

            const pastPendingRequests = await tokenContract.getPendingRequests();
            expect(existsId(pastPendingRequests, tokenId)).to.be.true;

            expect(existsId(await tokenContract.getUserPendingIds(user1.address), tokenId)).to.be.true;
            expect((Object.keys(await tokenContract.getUserRejectedIds(user1.address)) == 0)).to.be.true;
            expect((Object.keys(await tokenContract.getRejectedRequests()) == 0)).to.be.true;

            await tokenContract.rejectNFT(tokenId);
            
            expect(existsId(await tokenContract.getRejectedRequests(), tokenId)).to.be.true;
            expect(existsId(await tokenContract.getUserRejectedIds(user1.address), tokenId)).to.be.true;

            expect((await tokenContract.getPendingRequests()).length).to.be.eq.BN(pastPendingRequests.length - 1);
            expect(existsId(await tokenContract.getUserPendingIds(user1.address), tokenId)).to.be.false;

            expect((await tokenContract.fetchRejectedIdDetails(tokenId)).owner).to.equal(user1.address);
            expect((await tokenContract.fetchRejectedIdDetails(tokenId)).tokenURI).to.equal(tokenURI);
        });
    });

    describe('MintTo', function () {
        const tokenId = '1';
        it('mintTo', async function () {
            await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
            await tokenContract.connect(user2).mint(tokenURI, [user2.address], ['0'], {value: mintingFee});
            await tokenContract.connect(user1).mint(tokenURI, [user2.address], ['0'], {value: mintingFee});
            let PendingRequests = await tokenContract.getPendingRequests();

            expect(existsId(await tokenContract.getUserPendingIds(user1.address), tokenId)).to.be.true;
            expect(existsId(await tokenContract.getUserRejectedIds(user1.address), tokenId)).to.be.false;
            expect(existsId(await tokenContract.getRejectedRequests(), tokenId)).to.be.false;
            
            await tokenContract.rejectNFT(tokenId);

            expect((await tokenContract.getPendingRequests()).length).to.be.eq.BN(PendingRequests.length - 1);
            expect(existsId(await tokenContract.getUserPendingIds(user1.address), tokenId)).to.be.false;
            expect(existsId(await tokenContract.getRejectedRequests(), tokenId)).to.be.true;
            expect(existsId(await tokenContract.getUserRejectedIds(user1.address), tokenId)).to.be.true;
            
            await tokenContract.mintTo(tokenId);
            expect(existsId(await tokenContract.getUserPendingIds(user1.address), tokenId)).to.be.true;
            expect((await tokenContract.getPendingRequests()).length).to.equal(PendingRequests.length);

            expect(existsId(await tokenContract.getRejectedRequests(), tokenId)).to.be.false;
            expect(existsId(await tokenContract.getUserRejectedIds(user1.address), tokenId)).to.be.false;
        });

        describe('Burn', function () {
            const tokenId = '1';
            it('burn', async function () {
                await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
                await tokenContract.confirmNFT(tokenId);
                const totalSupply = await tokenContract.totalSupply();
                const userBalance = await tokenContract.balanceOf(user1.address);

                expect(await tokenContract.ownerOf(tokenId)).to.equal(user1.address);
                expect(existsId(await tokenContract.getUserRejectedIds(user1.address), tokenId)).to.be.false;
                expect(existsId(await tokenContract.getRejectedRequests(), tokenId)).to.be.false;
                
                await tokenContract.burn(tokenId);

                await expect(tokenContract.ownerOf(tokenId)).to.be.revertedWith('ERC721: owner query for nonexistent token');
                expect(existsId(await tokenContract.getUserRejectedIds(user1.address), tokenId)).to.be.true;
                expect(existsId(await tokenContract.getRejectedRequests(), tokenId)).to.be.true;
                expect(await tokenContract.totalSupply()).to.equal(totalSupply - 1);
                expect(await tokenContract.balanceOf(user1.address)).to.equal(userBalance - 1);
            });
        });
        
        describe('Transfer', function () {
            it('transfer', async function () {
                await tokenContract.connect(user1).mint(tokenURI, [user1.address], ['0'], {value: mintingFee});
                await tokenContract.confirmNFT(tokenId);
                
                expect(await tokenContract.ownerOf('1')).to.equal(user1.address);

                const user1Balance = await tokenContract.balanceOf(user1.address);
                const user2Balance = await tokenContract.balanceOf(user2.address);

                await expect(tokenContract.connect(user2).transfer(user2.address, '1')).to.be.revertedWith('ERC721: transfer from incorrect owner');
                await expect(tokenContract.connect(user1).transfer(constants.ZERO_ADDRESS, '1')).to.be.revertedWith('ERC721: transfer to the zero address');
                await tokenContract.connect(user1).transfer(user2.address, '1');
                expect(await tokenContract.balanceOf(user1.address)).to.equal(user1Balance - 1);
                expect(await tokenContract.balanceOf(user2.address)).to.equal(user2Balance + 1);
                expect(await tokenContract.ownerOf('1')).to.equal(user2.address);
            });
        });
    });
});

function existsId(data, id) {
    const result = data.every(element => {
        for (const [key, value] of Object.entries(element)) {
            if (key == '_hex') {
                if (web3.utils.hexToNumber(value) == id) {
                    // reject test
                    return false;
                } else {
                    return true;
                }
            }
        }
    });
    return !result;
}
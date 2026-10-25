import test from 'node:test';
import assert from 'node:assert/strict';
import {Interface,ZeroAddress} from 'ethers';
import {validateIntake,verifyMigratedNFT,encodeIntakeCalls,MIGRATIONS} from '../prepare-intake.mjs';
import {SAERO,TREASURY} from '../prepare-deployment.mjs';
const events=new Interface(['event Transfer(address indexed from,address indexed to,uint256 indexed tokenId)',
 'event VeNFTMigrated(address indexed depositor,address indexed recipient,uint256 indexed oldTokenId,uint256 amount,uint256 output,bool permanent,bool liquid)',
 'event Migrated(uint64 indexed nonce,address indexed recipient,uint256 amount,bool liquid)']);
const position=()=>({origin:'aerodrome',oldTokenId:'8814',tokenId:'99',principal:'100',transactionHash:'0x'+'ab'.repeat(32),blockNumber:100,blockHash:'0x'+'cd'.repeat(32)});
function receipt(origin='aerodrome') {
 const migration=MIGRATIONS[origin].address;
 const log=(address,name,args,index)=>({address,index,...events.encodeEventLog(events.getEvent(name),args)});
 return {status:1,logs:[log(SAERO.address,'Transfer',[ZeroAddress,migration,99],1),log(SAERO.address,'Transfer',[migration,TREASURY,99],2),
 origin==='aerodrome'?log(migration,'VeNFTMigrated',[TREASURY,TREASURY,8814,100,100,false,false],3):log(migration,'Migrated',[7,TREASURY,100,false],3)]};
}
test('intake requires actual reviewed IDs and canonical receipt fields, never predicted IDs',()=>{
 const p={schemaVersion:1,chainId:8453,positionsReviewed:true,recipient:'treasury',positions:[position()]};validateIntake(p);
 assert.throws(()=>validateIntake({...p,positionsReviewed:false}),/Reviewed/);
 assert.throws(()=>validateIntake({...p,positions:[{...position(),transactionHash:null}]}),/Actual migration/);
 assert.throws(()=>validateIntake({...p,positions:[position(),position()]}),/Duplicate/);
});
test('Base receipt must link canonical migration, old ID, principal, mint and Safe transfer',()=>{
 verifyMigratedNFT(position(),receipt());
 assert.throws(()=>verifyMigratedNFT({...position(),tokenId:'100'},receipt()),/selected received/);
 assert.throws(()=>verifyMigratedNFT({...position(),principal:'101'},receipt()),/principal mismatch/);
 const wrongRatio=receipt();wrongRatio.logs[2]={address:MIGRATIONS.aerodrome.address,index:3,...events.encodeEventLog(events.getEvent('VeNFTMigrated'),[TREASURY,TREASURY,8814,101,100,false,false])};
 assert.throws(()=>verifyMigratedNFT(position(),wrongRatio),/1:1/);
 const noMint=receipt();noMint.logs.shift();assert.throws(()=>verifyMigratedNFT(position(),noMint),/not minted/);
 const wrongEmitter=receipt();wrongEmitter.logs[2].address=TREASURY;assert.throws(()=>verifyMigratedNFT(position(),wrongEmitter),/lacks/);
});
test('OP settlement binds the actual nonce and cannot consume another settlement NFT',()=>{
 const p={...position(),origin:'velodrome',nonce:'7'};verifyMigratedNFT(p,receipt('velodrome'));
 assert.throws(()=>verifyMigratedNFT({...p,nonce:'8'},receipt('velodrome')),/lacks/);
});
test('finite and expired intake encodes only verified renew/upgrade methods and restores pause',()=>{
 const issuer='0x1111111111111111111111111111111111111111';
 const calls=encodeIntakeCalls(issuer,TREASURY,[{tokenId:'99',isPermanent:false,end:2000},{tokenId:'100',isPermanent:false,end:1},{tokenId:'101',isPermanent:true,end:0}],true,1000);
 const iface=new Interface(['function unpause()','function pause()','function increaseStakingPeriod(uint256,uint48)','function upgradeToPermanentStake(uint256)','function depositNFTs(address,uint256[])']);
 assert.deepEqual(calls.map((call)=>iface.parseTransaction(call).name),['unpause','upgradeToPermanentStake','increaseStakingPeriod','upgradeToPermanentStake','depositNFTs','pause']);
 assert.deepEqual(Array.from(iface.parseTransaction(calls[2]).args),[100n,1n]);
 const intake=iface.parseTransaction(calls[4]);assert.equal(intake.args[0],TREASURY);assert.deepEqual(Array.from(intake.args[1]),[99n,100n,101n]);
 assert(calls.every((call)=>call.value==='0'));
});

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * Solidity Contract Template based on
 * Source: https://etherscan.io/address/
 *
 * Add Introduction Here
 *
 * Add Summary Here
 *
 * Curated by @marcelc63 - marcelchristianis.com
 * Each functions have been annotated based on my own research.
 *
 * Feel free to use and modify as you see appropriate
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./library/Base64.sol";

interface Activity {
  function activityName() external returns (string memory);

  function activityDescription() external returns (string memory);

  function xpName() external returns (string memory);

  function xpForAdventurer(address) external returns (uint256);
}

interface SynthLoot {
  function weaponComponents(address walletAddress)
    external
    view
    returns (uint256[5] memory);
}

contract HelloDungeon is Activity {
  struct BossInstance {
    int32 hp;
    uint256 spawnBlock;
    uint256 killBlock;
  }

  struct Mechanics {
    uint256 purityLevel;
    uint256 weaknessLevel;
    uint256 damageLevel;
    uint256 stunLevel;
    bool bossSpawned;
    uint256 currentBossId;
    uint256 lastBossSpawnTime;
  }

  struct Spoils {
    uint256 fang;
    uint256 tail;
    uint256 mantle;
    uint256 horn;
    uint256 claw;
    uint256 eye;
    uint256 heart;
  }

  // synth loot can be redeployed anywhere; you can get the original source here:
  // https://etherscan.io/address/0x869ad3dfb0f9acb9094ba85228008981be6dbdde#readContract
  SynthLoot internal _synthLoot =
    SynthLoot(0x869Ad3Dfb0F9ACB9094BA85228008981BE6DBddE);
  Mechanics public mechanics;

  mapping(address => uint256) internal _xpMap;
  mapping(address => uint256) internal _lastActionMap;
  mapping(address => uint256) internal _lastBossActionMap;
  mapping(address => Spoils) internal _spoilsMap;
  mapping(uint256 => mapping(address => uint256)) internal _bossActionsTakenMap;
  mapping(uint256 => BossInstance) public bosses;

  function activityName() external pure override returns (string memory) {
    return "Hello Dungeon";
  }

  function activityDescription()
    external
    pure
    override
    returns (string memory)
  {
    return "Proof of concept public dungeon";
  }

  function xpName() external pure override returns (string memory) {
    return "Dungeoneering (Prototype) I";
  }

  function xpForAdventurer(address adventurer)
    external
    view
    override
    returns (uint256)
  {
    return _xpMap[adventurer];
  }

  function fight() public {
    require(
      block.timestamp - _lastActionMap[msg.sender] >= 6 hours,
      "too soon"
    );

    uint256 weaponId = _synthLoot.weaponComponents(msg.sender)[0];
    uint8 amount = 1;
    if (_xpMap[msg.sender] >= 48) {
      amount = 3;
    } else if (_xpMap[msg.sender] >= 12) {
      amount = 2;
    }

    if (weaponId >= 14) {
      // book
      mechanics.purityLevel += amount;
      _xpMap[msg.sender]++;
    } else if (weaponId >= 10) {
      // wand
      mechanics.weaknessLevel += amount;
      _xpMap[msg.sender]++;
    } else if (weaponId >= 5) {
      // blade
      mechanics.damageLevel += amount;
      _xpMap[msg.sender]++;
    } else {
      // bludgeon
      mechanics.stunLevel += amount;
      _xpMap[msg.sender]++;
    }

    _lastActionMap[msg.sender] = block.timestamp;
  }

  function spawnBoss() public {
    require(
      mechanics.purityLevel > 100 &&
        mechanics.weaknessLevel > 100 &&
        mechanics.damageLevel > 100 &&
        mechanics.stunLevel > 100,
      "conditions not met"
    );
    require(mechanics.bossSpawned == false, "already spawned");
    require(
      block.timestamp - mechanics.lastBossSpawnTime >= 3 hours,
      "last boss too recent"
    );

    BossInstance memory boss;
    boss.hp = 1000;
    boss.spawnBlock = block.number;
    mechanics.currentBossId++;
    mechanics.bossSpawned = true;
    mechanics.lastBossSpawnTime = block.timestamp;

    bosses[mechanics.currentBossId] = boss;
  }

  function fightBoss() public {
    require(mechanics.bossSpawned == true, "boss not spawned");
    require(
      block.timestamp - _lastBossActionMap[msg.sender] >= 10 minutes,
      "too soon"
    );

    bosses[mechanics.currentBossId].hp--;
    _bossActionsTakenMap[mechanics.currentBossId][msg.sender]++;

    _lastBossActionMap[msg.sender] = block.timestamp;

    if (bosses[mechanics.currentBossId].hp <= 0) {
      mechanics.bossSpawned = false;
      bosses[mechanics.currentBossId].killBlock = block.number;

      mechanics.purityLevel = 0;
      mechanics.weaknessLevel = 0;
      mechanics.damageLevel = 0;
      mechanics.stunLevel = 0;
    }
  }

  function spoilsUnclaimed(address owner, uint256 bossId)
    public
    view
    returns (uint256)
  {
    return _bossActionsTakenMap[bossId][owner];
  }

  function spoilsInventory(address owner) public view returns (Spoils memory) {
    return _spoilsMap[owner];
  }

  function claimSpoils(uint256 bossId, uint8 amount) public {
    require(bossId <= mechanics.currentBossId, "invalid boss id");
    require(bosses[bossId].hp <= 0, "boss not dead");
    require(_bossActionsTakenMap[bossId][msg.sender] > 0, "no spoils to claim");

    if (amount > 10) {
      amount = 10;
    }

    require(
      _bossActionsTakenMap[bossId][msg.sender] >= amount,
      "can't claim that many"
    );

    for (uint8 i = 0; i < amount; ++i) {
      _bossActionsTakenMap[bossId][msg.sender]--;

      uint256 rng = uint256(
        keccak256(
          abi.encodePacked(
            msg.sender,
            _bossActionsTakenMap[bossId][msg.sender],
            bosses[bossId].spawnBlock,
            bosses[bossId].killBlock
          )
        )
      );

      rng = rng % 100;
      if (rng > 98) {
        _spoilsMap[msg.sender].heart++;
      } else if (rng > 90) {
        _spoilsMap[msg.sender].eye++;
      }

      rng = rng % 5;
      if (rng == 0) {
        _spoilsMap[msg.sender].fang++;
      }
      if (rng == 1) {
        _spoilsMap[msg.sender].tail++;
      }
      if (rng == 2) {
        _spoilsMap[msg.sender].mantle++;
      }
      if (rng == 3) {
        _spoilsMap[msg.sender].horn++;
      }
      if (rng == 4) {
        _spoilsMap[msg.sender].claw++;
      }
    }
  }
}

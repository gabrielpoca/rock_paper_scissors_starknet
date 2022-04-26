import { Account } from "@shardlabs/starknet-hardhat-plugin/dist/account";
import { StarknetContract } from "@shardlabs/starknet-hardhat-plugin/dist/types";
import { expect } from "chai";
import { starknet } from "hardhat";
import { hash } from "starknet";

const ROCK = 1;
const PAPER = 2;
const SCISSORS = 3;
const PASS_ONE = 123;
const PASS_TWO = 234;

describe("Game", function () {
  this.timeout(120_000); // 30 seconds - recommended if used with starknet-devnet

  let contract: StarknetContract;
  let playerOne: Account;
  let playerTwo: Account;

  beforeEach(async () => {
    const contractFactory = await starknet.getContractFactory("Game");
    contract = await contractFactory.deploy();

    playerOne = await starknet.deployAccount("OpenZeppelin");
    playerTwo = await starknet.deployAccount("OpenZeppelin");
  });

  it("plays a game", async function () {
    await playPlayerOne(ROCK);
    await playPlayerTwo(PAPER);

    await revealPlayerOne(ROCK);
    await revealPlayerTwo(PAPER);

    const { game } = await contract.call("game", { game_id: 0 });

    expect(game.move_one).to.eq(BigInt(ROCK));
    expect(game.move_two).to.eq(BigInt(PAPER));
    expect(game.player_one).to.eq(BigInt(playerOne.starknetContract.address));
    expect(game.player_two).to.eq(BigInt(playerTwo.starknetContract.address));
    expect(game.winner).to.eq(BigInt(playerTwo.starknetContract.address));
  });

  it("mints an NFT fot the winner", async () => {
    await playPlayerOne(ROCK);
    await playPlayerTwo(PAPER);

    await revealPlayerOne(ROCK);
    await revealPlayerTwo(PAPER);

    const { owner } = await contract.call("ownerOf", {
      tokenId: { low: BigInt(0), high: BigInt(0) },
    });

    expect(owner).to.equal(BigInt(playerTwo.starknetContract.address));
  });

  it("ensures PAPER wins ROCK", async () => {
    await playPlayerOne(ROCK);
    await playPlayerTwo(PAPER);

    await revealPlayerOne(ROCK);
    await revealPlayerTwo(PAPER);

    const { game } = await contract.call("game", { game_id: 0 });

    expect(game.winner).to.eq(BigInt(playerTwo.starknetContract.address));
  });

  it("ensures ROCK wins SCISSORS", async () => {
    await playPlayerOne(ROCK);
    await playPlayerTwo(SCISSORS);

    await revealPlayerOne(ROCK);
    await revealPlayerTwo(SCISSORS);

    const { game } = await contract.call("game", { game_id: 0 });

    expect(game.winner).to.eq(BigInt(playerOne.starknetContract.address));
  });

  it("ensures SCISSORS wins PAPER", async () => {
    await playPlayerOne(PAPER);
    await playPlayerTwo(SCISSORS);

    await revealPlayerOne(PAPER);
    await revealPlayerTwo(SCISSORS);

    const { game } = await contract.call("game", { game_id: 0 });

    expect(game.winner).to.eq(BigInt(playerTwo.starknetContract.address));
  });

  it("has no winner when both play the same move", async () => {
    await playPlayerOne(PAPER);
    await playPlayerTwo(PAPER);

    await revealPlayerOne(PAPER);
    await revealPlayerTwo(PAPER);

    const { game } = await contract.call("game", { game_id: 0 });

    expect(game.winner).to.eq(0n);
  });

  describe("reveal", () => {
    it("fails if the game does not exist", async () => {
      await expect(revealPlayerOne(PAPER)).to.be.throw;
    });

    it("fails if the game is not finished", async () => {
      await playPlayerOne(PAPER);

      await expect(revealPlayerOne(PAPER)).to.be.throw;
    });
  });

  function playPlayerOne(move: number) {
    const hashedMove = BigInt(hash.pedersen([move, PASS_ONE]));

    return playerOne.invoke(contract, "start_game", {
      hashed_move: hashedMove,
    });
  }

  function playPlayerTwo(move: number) {
    const hashedMove = BigInt(hash.pedersen([move, PASS_TWO]));

    return playerTwo.invoke(contract, "play", {
      game_id: 0n,
      hashed_move_two: hashedMove,
    });
  }

  function revealPlayerOne(move: number) {
    return playerOne.invoke(contract, "reveal", {
      game_id: 0n,
      move: BigInt(move),
      pass: BigInt(PASS_ONE),
    });
  }

  function revealPlayerTwo(move: number) {
    return playerTwo.invoke(contract, "reveal", {
      game_id: 0n,
      move: BigInt(move),
      pass: BigInt(PASS_TWO),
    });
  }
});

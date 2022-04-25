%lang starknet

from starkware.cairo.common.math import split_felt
from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.hash import hash2
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero, assert_not_equal

from openzeppelin.token.erc721.library import (
    ERC721_name, ERC721_symbol, ERC721_balanceOf, ERC721_ownerOf, ERC721_getApproved,
    ERC721_isApprovedForAll, ERC721_tokenURI, ERC721_initializer, ERC721_approve,
    ERC721_setApprovalForAll, ERC721_transferFrom, ERC721_safeTransferFrom, ERC721_mint)

from openzeppelin.introspection.ERC165 import ERC165_supports_interface

from openzeppelin.access.ownable import Ownable_initializer, Ownable_only_owner

const NOP = 0
const ROCK = 1
const PAPER = 2
const SCISSORS = 3

struct Game:
    member player_one : felt
    member player_two : felt
    member hashed_move_one : felt
    member hashed_move_two : felt
    member move_one : felt
    member move_two : felt
    member winner : felt
end

@storage_var
func next_token_id_storage() -> (next_token_id : felt):
end

@storage_var
func player_one_storage(game_id : felt) -> (player : felt):
end

@storage_var
func player_two_storage(game_id : felt) -> (player : felt):
end

@storage_var
func hashed_move_one_storage(game_id : felt) -> (hashed_move : felt):
end

@storage_var
func hashed_move_two_storage(game_id : felt) -> (hashed_move : felt):
end

@storage_var
func move_one_storage(game_id : felt) -> (hashed_move : felt):
end

@storage_var
func move_two_storage(game_id : felt) -> (hashed_move : felt):
end

@storage_var
func winner_storage(game_id : felt) -> (winner : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    ERC721_initializer(name='ME', symbol='ME')
    return ()
end

@view
func game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(game_id : felt) -> (
        game : Game):
    let (player_one) = player_one_storage.read(game_id)
    let (player_two) = player_two_storage.read(game_id)
    let (hashed_move_one) = hashed_move_one_storage.read(game_id)
    let (hashed_move_two) = hashed_move_two_storage.read(game_id)
    let (move_one) = move_one_storage.read(game_id)
    let (move_two) = move_two_storage.read(game_id)
    let (winner) = winner_storage.read(game_id)

    let game = Game(
        player_one, player_two, hashed_move_one, hashed_move_two, move_one, move_two, winner)

    return (game)
end

@external
func start_game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        hashed_move : felt) -> (game_id : felt):
    alloc_locals

    let (_game_id) = new_game_id()
    local game_id = _game_id

    let (sender) = get_caller_address()
    player_one_storage.write(game_id, sender)

    hashed_move_one_storage.write(game_id, hashed_move)

    return (game_id)
end

@external
func play{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        game_id : felt, hashed_move_two : felt):
    let (hashed_move_one) = hashed_move_one_storage.read(game_id)

    with_attr error_message("Game {game_id} has not started."):
        assert_not_equal(hashed_move_one, NOP)
    end

    let (_hashed_move_two) = hashed_move_two_storage.read(game_id)

    with_attr error_message("Game {game_id} has already been played."):
        assert _hashed_move_two = NOP
    end

    let (sender) = get_caller_address()
    player_two_storage.write(game_id, sender)

    hashed_move_two_storage.write(game_id, hashed_move_two)

    return ()
end

@external
func reveal{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        game_id : felt, move : felt, pass : felt):
    let (hashed_move) = hash2{hash_ptr=pedersen_ptr}(move, pass)

    let (hashed_move_one) = hashed_move_one_storage.read(game_id)
    let (hashed_move_two) = hashed_move_two_storage.read(game_id)

    with_attr error_message("The game is not finished"):
        assert_not_zero(hashed_move_one)
        assert_not_zero(hashed_move_two)
    end

    if hashed_move == hashed_move_one:
        move_one_storage.write(game_id, move)
    else:
        if hashed_move == hashed_move_two:
            move_two_storage.write(game_id, move)
        else:
            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    end

    finish_game(game_id=game_id)

    return ()
end

func finish_game{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        game_id : felt) -> ():
    alloc_locals

    let (player_one) = player_one_storage.read(game_id)
    let (player_two) = player_two_storage.read(game_id)
    let (move_one) = move_one_storage.read(game_id)
    let (move_two) = move_two_storage.read(game_id)
    let (_game_id) = felt_to_uint256(game_id)

    if move_one == NOP:
        return ()
    end

    if move_two == NOP:
        return ()
    end

    # no one wins
    if move_two == move_one:
        return ()
    end

    if move_one == PAPER:
        if move_two == SCISSORS:
            ERC721_mint(player_two, _game_id)
            winner_storage.write(game_id, player_two)
        else:
            ERC721_mint(player_one, _game_id)
            winner_storage.write(game_id, player_one)
        end
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if move_one == ROCK:
        if move_two == PAPER:
            ERC721_mint(player_two, _game_id)
            winner_storage.write(game_id, player_two)
        else:
            ERC721_mint(player_one, _game_id)
            winner_storage.write(game_id, player_one)
        end
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    if move_one == SCISSORS:
        if move_two == ROCK:
            ERC721_mint(player_two, _game_id)
            winner_storage.write(game_id, player_two)
        else:
            ERC721_mint(player_one, _game_id)
            winner_storage.write(game_id, player_one)
        end
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    return ()
end

func new_game_id{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        game_id : felt):
    let (next_token_id) = next_token_id_storage.read()
    next_token_id_storage.write(next_token_id + 1)
    return (next_token_id)
end

func felt_to_uint256{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        x : felt) -> (x_ : Uint256):
    let (high, low) = split_felt(x)

    return (Uint256(low=low, high=high))
end

# Getters
#

@view
func supportsInterface{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        interfaceId : felt) -> (success : felt):
    let (success) = ERC165_supports_interface(interfaceId)
    return (success)
end

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC721_name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC721_symbol()
    return (symbol)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
        balance : Uint256):
    let (balance : Uint256) = ERC721_balanceOf(owner)
    return (balance)
end

@view
func ownerOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenId : Uint256) -> (owner : felt):
    let (owner : felt) = ERC721_ownerOf(tokenId)
    return (owner)
end

@view
func getApproved{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        tokenId : Uint256) -> (approved : felt):
    let (approved : felt) = ERC721_getApproved(tokenId)
    return (approved)
end

@view
func isApprovedForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, operator : felt) -> (isApproved : felt):
    let (isApproved : felt) = ERC721_isApprovedForAll(owner, operator)
    return (isApproved)
end

#
# Externals
#

@external
func approve{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        to : felt, tokenId : Uint256):
    ERC721_approve(to, tokenId)
    return ()
end

@external
func setApprovalForAll{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        operator : felt, approved : felt):
    ERC721_setApprovalForAll(operator, approved)
    return ()
end

@external
func transferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        from_ : felt, to : felt, tokenId : Uint256):
    ERC721_transferFrom(from_, to, tokenId)
    return ()
end

@external
func safeTransferFrom{pedersen_ptr : HashBuiltin*, syscall_ptr : felt*, range_check_ptr}(
        from_ : felt, to : felt, tokenId : Uint256, data_len : felt, data : felt*):
    ERC721_safeTransferFrom(from_, to, tokenId, data_len, data)
    return ()
end

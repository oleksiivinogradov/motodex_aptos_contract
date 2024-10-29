module motodex_addr::motodex {
    use std::option::Option;
    use aptos_framework::event;
    use aptos_framework::account::Account;

    use aptos_std::table::Table;
    // use std::bcs;
    // use std::error;
    use std::signer;
    use std::string::{Self, String};
    // use std::vector;
    use std::simple_map::{SimpleMap,Self};
    use std::vector;
    use aptos_framework::multisig_account::owners;

    use aptos_token::token;
    use aptos_token::token::TokenDataId;
    use aptos_token::token::TokenId;




    // struct TodoList has key {
    //     tasks: Table<u64, Task>,
    //     set_task_event: event::EventHandle<Task>,
    //     task_counter: u64
    // }
    //
    // struct Task has store, drop, copy {
    //     task_id: u64,
    //     address:address,
    //     content: String,
    //     completed: bool,
    // }

    // This struct stores an NFT collection's relevant information
    // struct ModuleData has key {
    //     token_data_id: TokenDataId,
    // }

    const MOTO_TYPE: u8 = 1;
    const TRACK_TYPE: u8 = 1;
    const HEALTH_TYPE: u8 = 1;

    /*
     /// A token ID.
    pub type TokenId = u32;
    /// MSDuration.
    pub type MSDuration = u64;
    pub type Health = u128;
    pub type Price = u128;
    pub type MSTimestamp = u64;
    pub type MotodexId = u8;
    pub type AffiliateId = AccountId;
    */

    struct Motodex has key, store {
        /// Mapping from token to owner.
        token_owner: SimpleMap<TokenId, Account>,
        // /// Contract owner account id
        owners: vector<address>,
        // /// Game server
        game_servers: vector<address>,
        // /// Ratio in basis points for minimal fee taken where 10000 = 100% (1 MAIN COIN)
        minimal_fee_rate: u32,
        // /// Epoch min duration in milliseconds
        epoch_minimal_interval: u64,
        // /// Max required num of motos per one game session
        max_moto_per_session: u64,
        /// `Track`, `Moto`, `HealthPill` for given token id
        token_types: SimpleMap<TokenId, u8>,
        /// Pairs represented health for given token id
        token_health: SimpleMap<TokenId, u128>,
        /// Pairs represented percent per track for givem track token id
        percent_for_track: SimpleMap<TokenId, u32>,
        /// MainCoin Price in USD
        price_main_coin_usd: u256,
        /// one MainCoin with decimals
        one_main_coin: u256,
        /// Converted
        game_sessions: SimpleMap<TokenId, GameSession>,
        /// Converted
        game_bids: SimpleMap<TokenId, TrackGameBid>,
        /// Converted
        previous_owners: SimpleMap<TokenId, address>,
        // struct to iterate over previous_owners
        previous_owners_token_ids: vector<TokenId>,
        /// Converted
        moto_owners: SimpleMap<TokenId, TokenInfo>,
        /// Converted
        tracks_owners: SimpleMap<TokenId, TokenInfo>,
        // struct to iterate over game_sessions
        track_token_ids: vector<TokenId>,
        /// in milliseconds
        latest_epoch_update: u64,
        /// counter
        counter: u256,
    }

    struct TokenInfo has key, store {
        owner_id: Option<address>,
        token_type: Option<u8>,
        active_session: Option<TokenId>,
        collected_fee: u256,
    }

    struct GameSessionMoto has key, store {
        moto_owner_id: Option<address>,
        moto_token_id: TokenId,
        last_track_time_result: u64,
    }

    struct GameBid has key, store  {
        amount: u256,
        moto: TokenId,
        timestamp: u64,
        bidder: Option<address>,
    }

    struct TrackGameBid has key, store {
        game_bids: vector<GameBid>,
    }

    struct EpochPayment has key, store {
        track_token_id: TokenId,
        moto_token_id: Option<TokenId>,
        receiver_type: u8,
        amount: u256,
        receiver_id: Option<address>,
    }

    struct GameSession has key, store {
        /// Time when this session was created
        init_time: u128,
        /// Cloned track token id for ping session
        track_token_id: TokenId,
        moto: vector<GameSessionMoto>,
        latest_update_time: u64,
        latest_track_time_result: u64,
        attempts: u8,
        game_bids_sum: u256,
        game_fees_sum: u256,
        /// stored current winner
        current_winner_moto: Option<GameSessionMoto>,
        epoch_payment: vector<EpochPayment>,
        max_moto_per_session: u64,
    }

    /// `init_module` is automatically called when publishing the module.
    /// In this function, we create an example NFT collection and an example token.
    fun init_module(source_account: &signer) {
        let list = vector::empty<address>();
        let account_addr = signer::address_of(source_account);
        vector::push_back(&mut list, account_addr);

        move_to(
            source_account,
            Motodex {
                token_owner : simple_map::create(),
                owners : list ,
                game_servers : list,
                minimal_fee_rate : 1 ,
                epoch_minimal_interval : 1,
                max_moto_per_session : 1000,
                token_types:  simple_map::create(),
                token_health:  simple_map::create(),
                percent_for_track:  simple_map::create(),
                price_main_coin_usd: 1,
                one_main_coin: 1,
                game_sessions:  simple_map::create(),
                game_bids: simple_map::create(),
                previous_owners: simple_map::create(),
                previous_owners_token_ids: vector::empty<TokenId>(),
                moto_owners: simple_map::create(),
                tracks_owners: simple_map::create(),
                track_token_ids: vector::empty<TokenId>(),
                latest_epoch_update: 0,
                counter: 0,
            }
        );
    }

    fun mint_nft(source_account: &signer) {
        let collection_name = string::utf8(b"Collection name");
        let description = string::utf8(b"Description");
        let collection_uri = string::utf8(b"Collection uri");
        let token_name = string::utf8(b"Token name");
        let token_uri = string::utf8(b"Token uri");
        // This means that the supply of the token will not be tracked.
        let maximum_supply = 0;
        // This variable sets if we want to allow mutation for collection description, uri, and maximum.
        // Here, we are setting all of them to false, which means that we don't allow mutations to any CollectionData fields.
        let mutate_setting = vector<bool>[ false, false, false ];

        // Create the nft collection.
        token::create_collection(source_account, collection_name, description, collection_uri, maximum_supply, mutate_setting);

        // Create a token data id to specify the token to be minted.
        let token_data_id = token::create_tokendata(
            source_account,
            collection_name,
            token_name,
            string::utf8(b""),
            0,
            token_uri,
            signer::address_of(source_account),
            1,
            0,
            // This variable sets if we want to allow mutation for token maximum, uri, royalty, description, and properties.
            // Here we enable mutation for properties by setting the last boolean in the vector to true.
            token::create_token_mutability_config(
                &vector<bool>[ false, false, false, false, true ]
            ),
            // We can use property maps to record attributes related to the token.
            // In this example, we are using it to record the receiver's address.
            // We will mutate this field to record the user's address
            // when a user successfully mints a token in the `mint_nft()` function.
            vector<String>[string::utf8(b"given_to")],
            vector<vector<u8>>[b""],
            vector<String>[ string::utf8(b"address") ],
        );

        // Store the token data id within the module, so we can refer to it later
        // when we're minting the NFT and updating its property version.
        // move_to(source_account, ModuleData {
        //     token_data_id,
        // });
    }


}

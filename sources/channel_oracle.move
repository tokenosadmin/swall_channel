/*
/// Module: swall_oracle
module swall_oracle::swall_oracle;
*/

/*
/// Module: oracle
module oracle::oracle;
*/
module swall_channel::channel_oracle {
    use std::string::{Self, String};
    use sui::event;
    use sui::tx_context::sender;
    use sui::object_table::{Self, ObjectTable};
    use sui::clock::{ Clock };
    use sui::coin::{Self, CoinMetadata};
    use std::type_name::{Self, TypeName};
    use std::ascii::{Self};
    /// Define a capability for the admin of the oracle.
    public struct ChannelOracleCap has key, store { id: UID }

    public struct CHANNEL_ORACLE has drop {}

    /// Define a struct for the SUI USD price oracle
    public struct PriceOracle has key, store {
        id: UID,
        /// The address of the oracle.
        creator: address,
        /// The name of the oracle.
        name: String,
        /// The description of the oracle.
        description: String,
        /// The current price of SUI in USD.
        token_price_mist: u64,
        /// The timestamp of the last update.
        last_update: u64,
    }

    public struct ChannelOracle has key, store {
        id: UID,
        oraceles: ObjectTable<String, PriceOracle>,
    }

    public struct PriceCreated has drop, copy {
        oracle_id: ID,
        type_name: String,
        creator: address,
        name: String,
        description: String,
        token_price_mist: u64,
        timestamp: u64,
    }

    public struct PriceUpdated has drop, copy {
        oracle_id: ID,
        type_name: String,
        old_price_mist: u64,
        new_price_mist: u64,
        timestamp: u64,
    }

    fun init(_channel_oracle: CHANNEL_ORACLE, ctx: &mut TxContext) {
         // Claim ownership of the one-time witness and keep it

        let cap = ChannelOracleCap { id: object::new(ctx) }; // Create a new admin capability object
        let channel_oracle = ChannelOracle {
            id: object::new(ctx),
            oraceles: object_table::new(ctx),
        };
        transfer::share_object(channel_oracle);
        transfer::public_transfer(cap, ctx.sender()); // Transfer the admin capability to the sender.
    }

    public fun add_oracle<T>(
        _: &ChannelOracleCap,
        channel_oracle: &mut ChannelOracle,
        metadata: &CoinMetadata<T>,
        token_price_mist: u64,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        let type_name = get_type_name<T>();
        let type_string = string::utf8(type_name);
        let oracle = PriceOracle {
            id: object::new(ctx),
            creator: sender(ctx),
            name: coin::get_name(metadata),
            description: coin::get_description(metadata),
            token_price_mist: token_price_mist,
            last_update: clock.timestamp_ms(),
        };
        event::emit(PriceCreated {
            oracle_id: object::uid_to_inner(&oracle.id),
            type_name: string::utf8(type_name),
            creator: sender(ctx),
            name: coin::get_name(metadata),
            description: coin::get_description(metadata),
            token_price_mist: token_price_mist,
            timestamp: clock.timestamp_ms(),
        });
        object_table::add(&mut channel_oracle.oraceles, type_string, oracle);
    }

        /// Update the SUI USD price
    public fun update_price(
        _: &ChannelOracleCap,
        channel_oracle: &mut ChannelOracle,
        type_name: vector<u8>,
        new_price_mist: u64,
        clock: &Clock,
    ) {
        let type_string = string::utf8(type_name);
        let oracle = object_table::borrow_mut(&mut channel_oracle.oraceles, type_string); 
        oracle.token_price_mist = new_price_mist;
        oracle.last_update = clock.timestamp_ms();
        event::emit(PriceUpdated {
            oracle_id: object::uid_to_inner(&oracle.id),
            type_name: type_string,
            old_price_mist: oracle.token_price_mist,
            new_price_mist: new_price_mist,
            timestamp: clock.timestamp_ms()
        });
    }

    public fun get_type_name<T>(): vector<u8> {
        let type_name: TypeName = type_name::get<T>();
        let typeBytes = ascii::into_bytes(type_name.into_string());
        typeBytes
    }
    

    /// Get the current SUI USD price
    public fun get_price(channel_oracle: &ChannelOracle, type_string: String): u64 {
        //let type_string = string::utf8(type_name);
        let oracle = object_table::borrow(&channel_oracle.oraceles, type_string); 
        oracle.token_price_mist
    }

    /// Get the last update timestamp
    public fun get_last_update(channel_oracle: &ChannelOracle, type_string: String): u64 {
        let oracle = object_table::borrow(&channel_oracle.oraceles, type_string); 
        oracle.last_update
    }

    #[test_only]
    public fun fetch_channel_oracle(ctx: &mut TxContext) {
        let channel_oracle = ChannelOracle {
            id: object::new(ctx),
            oraceles: object_table::new(ctx),
        };
        let channel_oracle_cap = ChannelOracleCap { id: object::new(ctx) };
        transfer::public_transfer(channel_oracle_cap, ctx.sender());
        // add_oracle(
        //     &channel_oracle_cap,
        //     &mut channel_oracle,
        //     b"sui_coin",
        //     &coin::SUI_METADATA,
        //     1000000000,
        //     clock::create_for_testing(ctx),
        //     ctx,
        // );
        transfer::share_object(channel_oracle);
    }
}


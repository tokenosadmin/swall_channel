/*
/// Module: swall
module swall::swall;
*/
#[allow(unused_use)]
// #[lint_allow(self_transfer)]
module swall_channel::channel {
   // use sui::object::{Self, ID, UID};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::sui::SUI;
    use sui::object_table::{Self, ObjectTable};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{sender};
    use sui::clock::{Self, Clock};
    use swall_channel::protocol::{Self, ChannelProtocolFee};
    use sui::event;
    use std::debug;
    use std::type_name::{Self, TypeName};
    use std::ascii::{Self};
    use swall_channel::subject::{Self, Interval};
    use swall_channel::subject::get_subject_fee;
    use sui::package;
    // Removed invalid use statement
    use swall_channel::channel_oracle::{Self, ChannelOracle};
    // use swall_oracle::swall_oracle::{Self, SwallOracle};

    
    public struct Channel has key {
        id: UID,
        owner: address,
        name: String,
        description: String,
        avatar: String,
    }

    public struct ChannelFeeCap has key, store { id: UID }

    public struct ChannelPool<phantom T> has key {
        id: UID,
        channel_id: ID,
        payment_token_type: String,
        current_price_usd_mist: u64,
        last_price_usd_mist: u64,
        balance: Balance<T>,
        owner: address,
        param: Param,
        no_of_licenses: u64,
        licenses: ObjectTable<address, LicenseMetadata>,
    }

    public struct License has key, store {
        id: UID,
        channel_id: ID,
        bought_license_price_usd_token_mist: u64,
        payment_token_type: String,
        owner: address,
        timestamp_ms: u64
    }

    public struct LicenseMetadata has key, store {
        id: UID,
        license_id: ID,
        channel_pool_id: ID,
        license_price_usd_token_mist: u64,
        payment_token_type: String,
        owner: address,
        timestamp_ms: u64
    }

    public struct ChannelCreated has copy, drop {
        id: ID,
        channel_id: ID,
        channel_pool_id: ID,
        owner: address,
        name: String,
        payment_token_type: String,
        timestamp_ms: u64
    }

    public struct LicenseBought has copy, drop {
        license_id: ID,
        channel_pool_id: ID,
        bought_license_price_usd_token_mist: u64,
        payment_token_type: String,
        buyer: address,
        buy_protocol_fee: u64,
        buy_subject_fee: u64,
        coefficient: u64,
        timestamp_ms: u64
    }

    public struct LicenseSold has copy, drop {
        license_id: ID,
        channel_pool_id: ID,
        sold_license_price_usd_token_mist: u64,
        payment_token_type: String,
        sell_subject_fee: u64,
        sell_protocol_fee: u64,
        coefficient: u64,
        seller: address,
        timestamp_ms: u64
    }

    public struct ParamUpdated has copy, drop {
        old_buy_protocol_fee: u64,
        old_sell_protocol_fee: u64,
        old_buy_subject_fee: u64,
        old_coefficient: u64,
        new_buy_protocol_fee: u64,
        new_sell_protocol_fee: u64,
        new_buy_subject_fee: u64,
        new_coefficient: u64,
        timestamp_ms: u64
    }

    public struct ChannelUpdated has copy, drop {
        id: ID,
        channel_id: ID,
        channel_pool_id: ID,
        owner: address,
        old_name: String,
        new_name: String,
        old_description: String,
        new_description: String,
        old_avatar: String,
        new_avatar: String,
        timestamp_ms: u64
    }

    public struct Param has store {
        buy_protocol_fee: u64,
        sell_protocol_fee: u64,
        buy_subject_fee: u64,
        coefficient: u64,
    }

    public struct ChannelFeeUsd has key, store {
        id: UID,
        price: u64,
        address: address,
        last_update: u64,
    }

    const INSUFFICIENT_FUND: u64 = 1;
    const LICENSE_EXISTS: u64 = 3;
    const NEW_COEFFICIENT_TOO_SMALL: u64 = 4;
    const LICENSE_NOT_FOUND: u64 = 5;
    const BUY_SUBJECT_FEE_TOO_HIGH: u64 = 6;
    const BUY_PROTOCOL_FEE_TOO_HIGH: u64 = 8;
    const SELL_PROTOCOL_FEE_TOO_HIGH: u64 = 9;
    const COEFFICIENT_TOO_HIGH: u64 = 10;
    const COEFFICIENT_TOO_LOW: u64 = 11;
    const BUY_SUBJECT_FEE_TOO_LOW: u64 = 12;
    const BUY_PROTOCOL_FEE_TOO_LOW: u64 = 14;
    const SELL_PROTOCOL_FEE_TOO_LOW: u64 = 15;
    const TOKEN_NOT_SUPPORTED: u64 = 20;

    public struct CHANNEL has drop {}

    fun init(otw: CHANNEL, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        let publisher = package::claim(otw, ctx);
        transfer::public_transfer(publisher, sender(ctx));
        // create global, make it share object
    }

    public fun update_channel_fee_usd(
        _: &ChannelFeeCap,
        channel_fee_usd: &mut ChannelFeeUsd,
        new_price: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        channel_fee_usd.price = new_price;
        channel_fee_usd.last_update = clock::timestamp_ms(clock);
        channel_fee_usd.address = sender(ctx);
    }

    public entry fun create_channel<T>(
        name: vector<u8>, 
        description: vector<u8>,
        avatar: vector<u8>,
        metadata: &CoinMetadata<T>,
        channel_protocol_fee: &ChannelProtocolFee,
        payment_mist: Coin<T>,
        channel_oracle: &ChannelOracle,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let inner_id = object::uid_to_inner(&id);
        let pool_id = object::new(ctx);
        let inner_pool_id = object::uid_to_inner(&pool_id);
        let license_id = object::new(ctx);
        let inner_license_id = object::uid_to_inner(&license_id);
        let license_metadata_id = object::new(ctx);
        let param = Param {
            buy_protocol_fee: 5,
            sell_protocol_fee: 5,
            buy_subject_fee: 5,
            coefficient: 1,
        };
        let type_name = get_type_name<T>();
        let multiplier = get_multiplier<T>(metadata);
        let value = coin::value(&payment_mist);
        let token_price_usd_mist = channel_oracle::get_price(channel_oracle, type_name);
        let channel_fee_usd = protocol::get_channel_protocol_fee_price(channel_protocol_fee);
        let network_fee_percent = protocol::get_channel_protocol_fee_percent(channel_protocol_fee);
        let network_fee_usd_mist_value = channel_fee_usd * multiplier * network_fee_percent / 100;
        let total_fee_usd_mist_value = channel_fee_usd * multiplier + network_fee_usd_mist_value;
        let channel_fee_token_mist = total_fee_usd_mist_value * multiplier / token_price_usd_mist;

        debug::print(&value);
        debug::print(&channel_fee_token_mist);
        assert!(value >= channel_fee_token_mist, INSUFFICIENT_FUND);

        let channel = Channel {
            id: id,
            owner: sender(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            avatar: string::utf8(avatar),
        };

        let mut channel_pool = ChannelPool<T> {
            id: pool_id,
            channel_id: inner_id,
            payment_token_type: type_name,
            current_price_usd_mist: 0,
            last_price_usd_mist: 0,
            balance: balance::zero(),
            owner: sender(ctx),
            param: param,
            no_of_licenses: 0,
            licenses: object_table::new(ctx),
        };
        event::emit(
            ChannelCreated {
                id: inner_id,
                channel_id: inner_id,
                channel_pool_id: inner_pool_id,
                owner: sender(ctx),
                name: string::utf8(name),
                payment_token_type: type_name,
                timestamp_ms: clock.timestamp_ms(),
            }
        );
        let license = License {
            id: license_id,
            channel_id: inner_id,
            payment_token_type: type_name,
            bought_license_price_usd_token_mist: 0,
            owner: sender(ctx),
            timestamp_ms: clock.timestamp_ms(),
        };
        let license_metadata = LicenseMetadata {
            id: license_metadata_id,
            license_id: inner_license_id,
            channel_pool_id: inner_pool_id,
            license_price_usd_token_mist: 0,
            payment_token_type: type_name,
            owner: sender(ctx),
            timestamp_ms: clock.timestamp_ms(),
        };
        event::emit(
            LicenseBought {
                license_id: inner_license_id,
                channel_pool_id: inner_pool_id,
                bought_license_price_usd_token_mist: 0,
                payment_token_type: type_name,
                buyer: sender(ctx),
                buy_protocol_fee: channel_pool.param.buy_protocol_fee,
                buy_subject_fee: channel_pool.param.buy_subject_fee,
                coefficient: channel_pool.param.coefficient,
                timestamp_ms: clock.timestamp_ms(),
            }
        );
        // debug::print(&sender(ctx));
        // debug::print(&license_metadata);
        // channel create event
        object_table::add(&mut channel_pool.licenses, sender(ctx), license_metadata);
        channel_pool.no_of_licenses = 1;
        channel_pool.current_price_usd_mist = get_channel_price_usd_mist(channel_pool.no_of_licenses, channel_pool.param.coefficient, metadata);
        transfer::public_transfer( payment_mist, protocol::get_channel_protocol_fee_wallet(channel_protocol_fee));
        transfer::transfer( license, sender(ctx));
        transfer::transfer( channel, sender(ctx));
        transfer::share_object(channel_pool);
    }

    public fun update_param<T>(_: &Channel, pool: &mut ChannelPool<T>, 
            buy_protocol_fee: u64, 
            sell_protocol_fee: u64, 
            buy_subject_fee: u64, 
            coefficient: u64, 
            clock: &Clock) {
        assert!(buy_protocol_fee <= 20, BUY_PROTOCOL_FEE_TOO_HIGH);
        assert!(buy_protocol_fee >= 1, BUY_PROTOCOL_FEE_TOO_LOW);
        
        assert!(buy_subject_fee <= 20, BUY_SUBJECT_FEE_TOO_HIGH);
        assert!(buy_subject_fee >= 1, BUY_SUBJECT_FEE_TOO_LOW);
        
        assert!(sell_protocol_fee <= 20, SELL_PROTOCOL_FEE_TOO_HIGH);
        assert!(sell_protocol_fee >= 1, SELL_PROTOCOL_FEE_TOO_LOW);

        assert!(coefficient >= pool.param.coefficient, NEW_COEFFICIENT_TOO_SMALL);
        assert!(coefficient <= 100, COEFFICIENT_TOO_HIGH);
        assert!(coefficient >= 1, COEFFICIENT_TOO_LOW);

        pool.param.buy_protocol_fee = buy_protocol_fee;
        pool.param.sell_protocol_fee = sell_protocol_fee;
        pool.param.buy_subject_fee = buy_subject_fee;
        pool.param.coefficient = coefficient;
        event::emit(ParamUpdated{
            old_buy_protocol_fee: pool.param.buy_protocol_fee,
            old_sell_protocol_fee: pool.param.sell_protocol_fee,
            old_buy_subject_fee: pool.param.buy_subject_fee,
            old_coefficient: pool.param.coefficient,
            new_buy_protocol_fee: buy_protocol_fee,
            new_sell_protocol_fee: sell_protocol_fee,
            new_buy_subject_fee: buy_subject_fee,
            new_coefficient: coefficient,
            timestamp_ms: clock::timestamp_ms(clock),
        })
    }

    public entry fun buy_license<T>(
        channel_protocol_fee: &ChannelProtocolFee,
        metadata: &CoinMetadata<T>,
        channel_oracle: &ChannelOracle,
        mut payment: Coin<T>, 
        channel_pool: &mut ChannelPool<T>, 
        clock: &Clock,
        ctx: &mut TxContext) {
            let licenseExists = object_table::contains(&channel_pool.licenses, sender(ctx));
            assert!(!licenseExists, LICENSE_EXISTS);
            let license_id = object::new(ctx);
            let inner_license_id = object::uid_to_inner(&license_id);
            let license_metadata_id = object::new(ctx);

            let type_name = get_type_name<T>();
            assert!(type_name == channel_pool.payment_token_type, TOKEN_NOT_SUPPORTED);

            let value = coin::value(&payment);
            let current_price_usd_mist = channel_pool.current_price_usd_mist;
            let token_price_usd_mist = channel_oracle::get_price(channel_oracle, type_name);
            let multiplier = get_multiplier<T>(metadata);
            let current_price_token_mist = current_price_usd_mist * multiplier / token_price_usd_mist;
            assert!(value >= current_price_token_mist, INSUFFICIENT_FUND);
            
            let license_subject_fee_percent = channel_pool.param.buy_subject_fee;
            let subjectFee = current_price_token_mist * license_subject_fee_percent / 100;
            let subject_coin = coin::split<T>(&mut payment, subjectFee, ctx);
            transfer::public_transfer(subject_coin, channel_pool.owner);

            let protocol_fee_percent = channel_pool.param.buy_protocol_fee;
            let protocolFee = current_price_token_mist * protocol_fee_percent / 100;
            let protocol_coin = coin::split<T>(&mut payment, protocolFee, ctx);
            transfer::public_transfer(protocol_coin, protocol::get_channel_protocol_fee_wallet(channel_protocol_fee));

            //let amount = current_price + subjectFee + protocolFee;
            let price_coin = coin::split<T>(&mut payment, current_price_token_mist - subjectFee - protocolFee, ctx);
            balance::join<T>(&mut channel_pool.balance, coin::into_balance<T>(price_coin));
            
            //debug::print(&channel_pool.balance);
            //transfer::public_transfer(coin::split(&mut payment, current_price, ctx), object::uid_to_address(&pool.id));
            //transfer::public_transfer(coin::split(&mut payment, subjectFee, ctx), channel_pool.owner);
            transfer::public_transfer(payment, tx_context::sender(ctx));

            let license = License {
                id: license_id,
                channel_id: object::uid_to_inner(&channel_pool.id),
                bought_license_price_usd_token_mist: current_price_usd_mist,
                payment_token_type: type_name,
                owner: sender(ctx),
                timestamp_ms: clock.timestamp_ms(),
            };
            let license_metadata = LicenseMetadata {
                id: license_metadata_id,
                license_id: inner_license_id,
                channel_pool_id: object::uid_to_inner(&channel_pool.id),
                payment_token_type: type_name,
                license_price_usd_token_mist: current_price_usd_mist,
                owner: sender(ctx),
                timestamp_ms: clock.timestamp_ms(),
            };
            event::emit(
                LicenseBought {
                    license_id: inner_license_id,
                    channel_pool_id: object::uid_to_inner(&channel_pool.id),
                    bought_license_price_usd_token_mist: current_price_usd_mist,
                    payment_token_type: type_name,
                    buyer: sender(ctx),
                    buy_subject_fee: license_subject_fee_percent,
                    buy_protocol_fee: protocol_fee_percent,
                    coefficient: channel_pool.param.coefficient,
                    timestamp_ms: clock.timestamp_ms(),
                }
            );
            object_table::add(&mut channel_pool.licenses, sender(ctx), license_metadata);
            channel_pool.no_of_licenses = channel_pool.no_of_licenses + 1;
            channel_pool.last_price_usd_mist = current_price_usd_mist;
            channel_pool.current_price_usd_mist = get_channel_price_usd_mist(channel_pool.no_of_licenses, channel_pool.param.coefficient, metadata);
            transfer::transfer(license, sender(ctx));
        }
    
    public entry fun sell_license<T>(
        channel_protocol_fee: &ChannelProtocolFee,
        channel_pool: &mut ChannelPool<T>, 
        metadata: &CoinMetadata<T>,
        channel_oracle: &ChannelOracle,
        clock: &Clock, 
        interval: &Interval,
        ctx: &mut TxContext) {
            let licenseExists = object_table::contains(&channel_pool.licenses, sender(ctx));
            assert!(licenseExists, LICENSE_NOT_FOUND);
             
            let bought_ms = object_table::borrow(&channel_pool.licenses, sender(ctx)).timestamp_ms;
            let sold_ms = clock::timestamp_ms(clock);
            let sell_subject_fee_percent = get_subject_fee(interval, bought_ms, sold_ms);
            let sell_protocol_fee_percent = channel_pool.param.sell_protocol_fee;
            let buy_protocol_fee_percent = channel_pool.param.buy_protocol_fee;
            let buy_subject_fee_percent = channel_pool.param.buy_subject_fee;
            let coefficient = channel_pool.param.coefficient;
            let type_name = get_type_name<T>();
            assert!(type_name == channel_pool.payment_token_type, TOKEN_NOT_SUPPORTED);

            let multiplier = get_multiplier<T>(metadata);
            let token_price_usd_mist = channel_oracle::get_price(channel_oracle, type_name);
            
            let to_be_sold_price_usd_mist = channel_pool.last_price_usd_mist;
            let to_be_sold_price_token_mist = to_be_sold_price_usd_mist * multiplier / token_price_usd_mist;
            let buySubjectFee = to_be_sold_price_token_mist * buy_subject_fee_percent / 100;
            let buyProtocolFee = to_be_sold_price_token_mist * buy_protocol_fee_percent / 100;
            // remove coin from pool
            let mut revenue = balance::split(&mut channel_pool.balance, to_be_sold_price_token_mist -  buySubjectFee -  buyProtocolFee);
            let revenue_value = balance::value(&revenue);
            let sellSubjectFee = revenue_value * sell_subject_fee_percent / 100;
            let sellProtocolFee = revenue_value * sell_protocol_fee_percent / 100;

            let subject = balance::split(&mut revenue, sellSubjectFee);
            let subject_coin = coin::from_balance(subject, ctx);
            let protocol = balance::split(&mut revenue, sellProtocolFee);
            let protocol_coin = coin::from_balance(protocol, ctx);

            let revenue_coin = coin::from_balance(revenue, ctx);

            transfer::public_transfer(revenue_coin, sender(ctx));
            transfer::public_transfer(subject_coin, channel_pool.owner);
            transfer::public_transfer(protocol_coin, protocol::get_channel_protocol_fee_wallet(channel_protocol_fee));

            let licensenft = object_table::remove(&mut channel_pool.licenses, sender(ctx));
            
            let LicenseMetadata {
                id: license_id,
                license_id:  _,
                channel_pool_id:  _,
                license_price_usd_token_mist: _,
                payment_token_type: _,
                owner: _,
                timestamp_ms: _
            } = licensenft;
            let inner_license_id = object::uid_to_inner(&license_id);
            
            event::emit(LicenseSold{
                license_id: inner_license_id,
                channel_pool_id: object::uid_to_inner(&channel_pool.id),
                sold_license_price_usd_token_mist: to_be_sold_price_usd_mist,
                payment_token_type: type_name,
                seller: sender(ctx),
                sell_subject_fee: sell_subject_fee_percent,
                sell_protocol_fee: sell_protocol_fee_percent,
                coefficient: coefficient,
                timestamp_ms: clock.timestamp_ms(),
            });
            object::delete(license_id);
            channel_pool.no_of_licenses = channel_pool.no_of_licenses - 1;
            channel_pool.last_price_usd_mist = to_be_sold_price_usd_mist;
            channel_pool.current_price_usd_mist = get_channel_price_usd_mist(channel_pool.no_of_licenses, channel_pool.param.coefficient, metadata);    
    }

    public fun get_channel_price_usd_mist <T>(no_of_licenses: u64, cofficient: u64, metadata: &CoinMetadata<T>): u64 {
        let multiplier =get_multiplier(metadata);
        let price = no_of_licenses * no_of_licenses * multiplier / 100 * (cofficient);
        (price)
    }

    public fun get_multiplier<T>(metadata: &CoinMetadata<T>): u64 {
        let decimals = coin::get_decimals(metadata);
        let mut i: u8 = 0;
        let mut multiplier = 1;       
        while (i < decimals) { 
            multiplier = multiplier * 10;
            i = i + 1;
        };
        multiplier
    }
    public fun get_type_name<T>(): String {
        let type_name: TypeName = type_name::get<T>();
        let typeBytes = ascii::into_bytes(type_name.into_string());
        let str = string::utf8(typeBytes);
        str
    } 

    public fun edit_channel<T>(
        channel: &mut Channel,
        pool: &mut ChannelPool<T>,
        name: vector<u8>,
        description: vector<u8>,
        avatar: vector<u8>,
        clock: &Clock,
        ctx: &mut TxContext,
    ) {
        channel.name = string::utf8(name);
        channel.description = string::utf8(description);
        channel.avatar = string::utf8(avatar);
        event::emit(ChannelUpdated {
            id: object::uid_to_inner(&channel.id),
            channel_id: object::uid_to_inner(&channel.id),
            channel_pool_id: object::uid_to_inner(&pool.id),
            owner: sender(ctx),
            old_name: channel.name,
            new_name: string::utf8(name),
            old_description: channel.description,
            new_description: string::utf8(description),
            old_avatar: channel.avatar,
            new_avatar: string::utf8(avatar),
            timestamp_ms: clock::timestamp_ms(clock),
        });
    }

    #[test_only]
    public fun init_for_testing(otw: CHANNEL, ctx: &mut TxContext) {
        init(otw, ctx);
    }

    #[test_only]
    public fun fetch_channel_fee_usd(ctx: &mut TxContext) {
        let price = ChannelFeeUsd {
            id: object::new(ctx),
            address: ctx.sender(),
            price: 5,
            last_update: 0
        };
        transfer::share_object(price);
    }

}

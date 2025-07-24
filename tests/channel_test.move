#[test_only]
#[allow(unused_use)]
module swall_channel::channel_test {
    use sui::test_scenario as ts;
    use sui::test_utils;
    use swall_channel::channel::{Self, Channel, ChannelPool, CHANNEL, Param, LicenseMetadata, License, ChannelFeeUsd};
    use sui::sui::SUI;
    use sui::object_table;
    use sui::clock::{Self, Clock};
    use swall_channel::subject::{Self, Interval};
    use swall_channel::channel_oracle::{Self, ChannelOracle};
    use swall_channel::protocol::{Self, ChannelProtocolFee};
    //use swall_coin::sui_coin::{Self, SUI_COIN};
    use sui::coin::{Self, Coin};
    use std::debug;

    const ADMIN: address = @0xAD;
    // const ALICE: address = @0xA;
    // const BOB: address = @0xB;

    // const MINIMUM_FUND: u64 = 2000000000;

    #[test]
    fun test_get_type_name() {
        let type_name = channel::get_type_name<ChannelProtocolFee>();
        debug::print(&type_name);
    }

    #[test]
    fun test_create() { 
        let mut ts = ts::begin(ADMIN);
        {
            ts::next_tx(&mut ts, ADMIN);
            channel::init_for_testing(
                test_utils::create_one_time_witness<CHANNEL>(), 
                ts::ctx(&mut ts)
            );
            subject::create_interval(ts::ctx(&mut ts));
            channel_oracle::fetch_channel_oracle(ts::ctx(&mut ts));
            channel::fetch_channel_fee_usd(ts::ctx(&mut ts));
            protocol::create_channel_protocol_fee(ts::ctx(&mut ts));
        };
        // {
        //     ts::next_tx(&mut ts, ADMIN);
        //     let channel_oracle_cap = ts::take_from_sender(&ts);
        //     let channel_oracle = ts::take_shared(&ts);
            
        //     channel_oracle::add_oracle<SUI>(
        //         &channel_oracle_cap,
        //         &mut channel_oracle,
        //         b"0x2::sui::SUI",
        //         &coin::SUI_METADATA,
        //         1000000000,
        //         &clock::create_for_testing(ts::ctx(&mut ts)),
        //         ts::ctx(&mut ts),
        //     );
        //     ts::return_shared<ChannelOracle>(channel_oracle);
        //     ts::return_to_sender(&ts, channel_oracle_cap);
        // };
        // {
        //     ts::next_tx(&mut ts, ALICE);
        //     let coin = coin::mint_for_testing<SUI>(MINIMUM_FUND, ts::ctx(&mut ts));
        //     let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
        //     let sui_usd_price: ChannelOracle = ts::take_shared(&ts);
        //     let channel_fee_usd: ChannelFeeUsd = ts::take_shared(&ts);
        //     let channel_protocol_fee: ChannelProtocolFee = ts::take_shared(&ts);
        //     channel::create_channel(
        //         b"alice",
        //         b"bio",
        //         b"avatar",
        //         &channel_protocol_fee,
        //         coin,
        //         &sui_usd_price,
        //         &clock,
        //         ts::ctx(&mut ts)
        //     );
        //     clock::destroy_for_testing(clock);
        //     ts::return_shared<ChannelOracle>(sui_usd_price);
        //     ts::return_shared<ChannelFeeUsd>(channel_fee_usd);
        //     ts::return_shared<ChannelProtocolFee>(channel_protocol_fee);
        // };
        // {
        //     ts::next_tx(&mut ts, ALICE);
        //     assert!(ts::has_most_recent_for_sender<Channel>(&ts), 1);
        //     assert!(ts::has_most_recent_shared<ChannelPool>(), 1);
        //     assert!(ts::has_most_recent_for_sender<License>(&ts), 1);
            
        // };
        // {
        //     ts::next_tx(&mut ts, ALICE);
        //     let coin = coin::mint_for_testing<SUI>(MINIMUM_FUND, ts::ctx(&mut ts));
        //     let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
        //     channel_oracle::fetch_channel_oracle(ts::ctx(&mut ts));
        //     channel::fetch_channel_fee_usd(ts::ctx(&mut ts));
        //     let channel_fee_usd: ChannelFeeUsd = ts::take_shared(&ts);
        //     let sui_usd_price: ChannelOracle = ts::take_shared(&ts);
        //     let channel_protocol_fee: ChannelProtocolFee = ts::take_shared(&ts);
        //     channel::create_channel(
        //         b"alice",
        //         b"bio",
        //         b"avatar",
        //         &channel_protocol_fee,
        //         coin,
        //         &sui_usd_price,
        //         &clock,
        //         ts::ctx(&mut ts)
        //     );
        //     clock::destroy_for_testing(clock);
        //     ts::return_shared<ChannelOracle>(sui_usd_price);
        //     ts::return_shared<ChannelFeeUsd>(channel_fee_usd);
        //     ts::return_shared<ChannelProtocolFee>(channel_protocol_fee);
        //     //coin::burn_for_testing(coin);
        // };
        // {
        //     ts::next_tx(&mut ts, BOB);
        //     let mut channel_pool: ChannelPool = ts::take_shared(&ts);
        //     let channel_protocol_fee: ChannelProtocolFee = ts::take_shared(&ts);
        //     let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
        //     let coin = coin::mint_for_testing<SUI>(MINIMUM_FUND, ts::ctx(&mut ts));
        //     channel::buy_license(&channel_protocol_fee,
        //         coin, &mut channel_pool, &clock, ts::ctx(&mut ts));
        //     ts::return_shared<ChannelPool>(channel_pool);
        //     ts::return_shared<ChannelProtocolFee>(channel_protocol_fee);
        //     clock::destroy_for_testing(clock);
        //     //coin::burn_for_testing(coin);
        // };
        // {
        //     ts::next_tx(&mut ts, BOB);
        //     assert!(ts::has_most_recent_for_sender<License>(&ts), 1);
        // };
        // {
        //     ts::next_tx(&mut ts, ALICE);
        //     let mut channel_pool: ChannelPool = ts::take_shared(&ts);
        //     let channel_protocol_fee: ChannelProtocolFee = ts::take_shared(&ts);
        //     let interval: Interval = ts::take_shared(&ts);
        //     let clock: Clock = clock::create_for_testing(ts::ctx(&mut ts));
        //     channel::sell_license(
        //         &channel_protocol_fee, 
        //         &mut channel_pool, 
        //         &clock, 
        //         &interval, 
        //         ts::ctx(&mut ts)
        //     );
        //     ts::return_shared<ChannelPool>(channel_pool);
        //     ts::return_shared<Interval>(interval);
        //     clock::destroy_for_testing(clock);
        //     ts::return_shared<ChannelProtocolFee>(channel_protocol_fee);
        // };
        ts::end(ts);
    }
}
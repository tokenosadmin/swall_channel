
#[allow(unused_use)]
module swall_channel::protocol {
    use sui::package;
    use sui::tx_context::{sender};
    use sui::event;
    use sui::clock::{Self, Clock};

    public struct PROTOCOL has drop {}

    public struct AdminCap has key, store {
        id: UID
    }

    public struct UpdateFeeCap has key, store {
        id: UID,
        expires_at: u64,
    }


    public struct ChannelProtocolFee has key, store {
        id: UID,
        protocol_fee_percent: u64,
        protocol_fee_wallet: address,
        price: u64,
    }


    //const ONE_MINITE: u64 = 60000;
    const ONE_DAY: u64 = 86400000;
    // const THREE_DAYS: u64 = 259200000;
    // const FIVE_DAYS: u64 = 432000000;
    // const TEN_DAYS: u64 = 864000000;
    //const THIRTY_DAYS: u64 = 2592000000;


    const UPDATE_CAP_EXPIRED: u64 = 0;
    // const FEE_TOO_SMALL: u64 = 1;
    //const SOLD_EARLIER_THAN_BOUGHT: u64 = 2;

    fun init(_otw: PROTOCOL, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        // let publisher = package::claim(otw, ctx);
        // transfer::public_transfer(publisher, sender(ctx));
        // let admin = AdminCap {
        //     id: object::new(ctx),
        // };
        //debug::print(&global_profiles);
        //transfer::public_transfer(admin, sender(ctx));

       let channel_protocol_fee = ChannelProtocolFee {
            id: object::new(ctx),
            protocol_fee_percent: 6,
            protocol_fee_wallet: sender(ctx),
            price: 5
        };
        transfer::share_object(channel_protocol_fee);
    }

    public fun authorize(_: &AdminCap, user: address, ctx: &mut TxContext, clock: &Clock) {
        let current_ms = clock::timestamp_ms(clock);
        let feeCap = UpdateFeeCap {
            id: object::new(ctx),
            expires_at: current_ms + ONE_DAY
        };
        //debug::print(&global_profiles);
        transfer::public_transfer(feeCap, user);
    }


    public fun update_channel_protocol_fee(cap: &UpdateFeeCap, ccpf: &mut ChannelProtocolFee,
        protocol_fee_percent: u64, protocol_fee_wallet: address,
        clock: &Clock,
    ) {
        let current = clock::timestamp_ms(clock);
        assert!(cap.expires_at > current, UPDATE_CAP_EXPIRED);
        ccpf.protocol_fee_percent = protocol_fee_percent;
        ccpf.protocol_fee_wallet = protocol_fee_wallet;
    }

    public fun get_channel_protocol_fee_percent(ccpf: &ChannelProtocolFee): u64 {
        ccpf.protocol_fee_percent
    }

    public fun get_channel_protocol_fee_price(ccpf: &ChannelProtocolFee): u64 {
        ccpf.price
    }

    public fun get_channel_protocol_fee_wallet(ccpf: &ChannelProtocolFee): address {
        ccpf.protocol_fee_wallet
    }

    #[test_only]
    public fun init_for_testing(otw: PROTOCOL, ctx: &mut TxContext) {
        init(otw, ctx);
    }

    #[test_only]
    public fun create_channel_protocol_fee(ctx: &mut TxContext) {
        let channel_protocol_fee = ChannelProtocolFee {
            id: object::new(ctx),
            protocol_fee_percent: 6,
            protocol_fee_wallet: sender(ctx),
            price: 5
        };
        transfer::share_object(channel_protocol_fee);
    }

}
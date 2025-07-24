
#[allow(unused_use)]
module swall_channel::subject {
    use sui::event;
    use sui::package;
    use sui::tx_context::{sender};
    use sui::clock::{Self, Clock};

    public struct SUBJECT has drop {}

    public struct AdminCap has key, store {
        id: UID
    }

    public struct UpdateFeeCap has key, store {
        id: UID,
        expires_at: u64,
    }

        //const ONE_MINITE: u64 = 60000;
    const ONE_DAY: u64 = 86400000;
    // const THREE_DAYS: u64 = 259200000;
    // const FIVE_DAYS: u64 = 432000000;
    // const TEN_DAYS: u64 = 864000000;
    //const THIRTY_DAYS: u64 = 2592000000;

    public struct Interval has key, store {
        id: UID,
        short: Short,
        long: Long,
        hold: Hold,
        hold_tight: HoldTight
    }

    public struct Short has store {
        short_fee_percent: u64,
        short_interval: u64,
    }

    public struct Long has store {
        long_fee_percent: u64,
        long_interval: u64,
    }

    public struct Hold has store {
        hold_fee_percent: u64,
        hold_interval: u64,
    }

    public struct HoldTight has store {
        hold_tight_fee_percent: u64,
        hold_tight_interval: u64,
    }

    public struct ProtocolFeeUpdated has copy, drop {
        old_short_fee_percent: u64,
        old_short_interval: u64,
        old_long_fee_percent: u64,
        old_long_interval: u64,
        old_hold_fee_percent: u64,
        old_hold_interval: u64,
        old_hold_tight_fee_percent: u64,
        new_short_fee_percent: u64,
        new_short_interval: u64,
        new_long_fee_percent: u64,
        new_long_interval: u64,
        new_hold_fee_percent: u64,
        new_hold_interval: u64,
        new_hold_tight_fee_percent: u64,
        timestamp_ms: u64
    }

    const UPDATE_CAP_EXPIRED: u64 = 0;
    // const FEE_TOO_SMALL: u64 = 1;
    const SOLD_EARLIER_THAN_BOUGHT: u64 = 2;

    fun init(_otw: SUBJECT, ctx: &mut TxContext) {
        // Claim the `Publisher` for the package!
        let admin = AdminCap {
            id: object::new(ctx),
        };
        //debug::print(&global_profiles);
        transfer::public_transfer(admin, sender(ctx));
        let short = Short {
            short_fee_percent: 20,
            short_interval: 86400000,
        };
        let long = Long {
            long_fee_percent: 15,
            long_interval: 864000000,
        };
        let hold = Hold {
            hold_fee_percent: 10,
            hold_interval: 2592000000,
        };
        let hold_tight = HoldTight {
            hold_tight_fee_percent: 5,
            hold_tight_interval: 18446744073709551615,
        };
        let interval = Interval {
            id: object::new(ctx),
            short: short,
            long: long,
            hold: hold,
            hold_tight: hold_tight
        };
        transfer::share_object(interval);
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

    public(package) fun get_subject_fee(interval: &Interval, boght_ms: u64, sold_ms: u64) : u64  {
        let mut result: u64 = 5;
        let actual_interval = sold_ms - boght_ms;
        assert!(actual_interval >= 0, SOLD_EARLIER_THAN_BOUGHT);
        if (actual_interval <= interval.short.short_interval) {
            result = interval.short.short_fee_percent;
        };
        if (actual_interval <= interval.long.long_interval && actual_interval > interval.short.short_interval) {
            result = interval.long.long_fee_percent;
        };
        if (actual_interval <= interval.hold.hold_interval && actual_interval > interval.long.long_interval) {
            result = interval.hold.hold_fee_percent;
        };  
        if (actual_interval <= interval.hold_tight.hold_tight_interval && actual_interval > interval.hold.hold_interval) {
            result = interval.hold_tight.hold_tight_fee_percent;
        };
        (result)
    }

    public fun update_protocol_fee(cap: &UpdateFeeCap, interval: &mut Interval,
        short_fee_percent: u64, short_interval: u64,
        long_fee_percent: u64, long_interval: u64,
        hold_fee_percent: u64, hold_interval: u64, hold_tight_fee_percent: u64,
        clock: &Clock,
    ) {
        let current = clock::timestamp_ms(clock);
        assert!(cap.expires_at > current, UPDATE_CAP_EXPIRED);
        interval.short.short_fee_percent = short_fee_percent;
        interval.short.short_interval = short_interval;
        interval.long.long_fee_percent = long_fee_percent;
        interval.long.long_interval = long_interval;
        interval.hold.hold_fee_percent = hold_fee_percent;
        interval.hold.hold_interval = hold_interval;
        interval.hold_tight.hold_tight_fee_percent = hold_tight_fee_percent;
        event::emit( 
        ProtocolFeeUpdated {
            old_short_fee_percent: interval.short.short_fee_percent,
            old_short_interval: interval.short.short_interval,
            old_long_fee_percent: interval.long.long_fee_percent,
            old_long_interval: interval.long.long_interval,
            old_hold_fee_percent: interval.hold.hold_fee_percent,
            old_hold_interval: interval.hold.hold_interval,
            old_hold_tight_fee_percent: interval.hold_tight.hold_tight_fee_percent,
            new_short_fee_percent: short_fee_percent,
            new_short_interval: short_interval,
            new_long_fee_percent: long_fee_percent,
            new_long_interval: long_interval,
            new_hold_fee_percent: hold_fee_percent,
            new_hold_interval: hold_interval,
            new_hold_tight_fee_percent: hold_tight_fee_percent,
            timestamp_ms: clock::timestamp_ms(clock),
        });
    }


    #[test_only]
    public fun init_for_testing(otw: SUBJECT, ctx: &mut TxContext) {
        init(otw, ctx);
    }

    #[test_only]
    public fun create_interval(ctx: &mut TxContext) {
                let short = Short {
            short_fee_percent: 20,
            short_interval: 86400000,
        };
        let long = Long {
            long_fee_percent: 15,
            long_interval: 864000000,
        };

        let hold = Hold {
            hold_fee_percent: 10,
            hold_interval: 2592000000,
        };
        let hold_tight = HoldTight {
            hold_tight_fee_percent: 5,
            hold_tight_interval: 18446744073709551615,
        };
        let interval = Interval {
            id: object::new(ctx),
            short: short,
            long: long,
            hold: hold,
            hold_tight: hold_tight
        };
        transfer::share_object(interval);
    }
}
package utils

import (
	"context"

	cosmos "github.com/cosmos/cosmos-sdk/types"
	stakingmodule "github.com/cosmos/cosmos-sdk/x/staking/types"
)

// BankKeeper defines the exposed interface for using functionality of the bank keeper
// in the context of the AnteHandler utils package.
type BankKeeper interface {
	GetBalance(ctx context.Context, addr cosmos.AccAddress, denom string) cosmos.Coin
}

// DistributionKeeper defines the exposed interface for using functionality of the distribution
// keeper in the context of the AnteHandler utils package.
type DistributionKeeper interface {
	WithdrawDelegationRewards(ctx context.Context, delAddr cosmos.AccAddress, valAddr cosmos.ValAddress) (cosmos.Coins, error)
}

// StakingKeeper defines the exposed interface for using functionality of the staking keeper
// in the context of the AnteHandler utils package.
type StakingKeeper interface {
	BondDenom(ctx context.Context) (string, error)
	IterateDelegations(ctx context.Context, delAddr cosmos.AccAddress,
		fn func(index int64, del stakingmodule.DelegationI) (stop bool),
	) error
}

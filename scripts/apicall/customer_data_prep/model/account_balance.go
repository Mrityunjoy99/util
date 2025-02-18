package model

import (
	"fmt"
	"time"
)

type AccountBalance struct {
	AccountId           int       `gorm:"column:account_id"`
	CheckerClearBalance float64   `gorm:"column:checker_clear_balance"`
	AvailableBalance    float64   `gorm:"column:available_balance"`
	LatestTxnDate       time.Time `gorm:"column:txn_date"`
}

func (AccountBalance) TableName() string {
	return "account_balance"
}

func (a *AccountBalance) GetLatestTxnDateStr() string {
	return a.LatestTxnDate.Format("2006-01-02")
}

func (a *AccountBalance) Print() {
	fmt.Printf("Account ID: %d\nChecker Clear Balance: %f\nAvailable Balance: %f\nTransaction Date: %s\n", a.AccountId, a.CheckerClearBalance, a.AvailableBalance, a.GetLatestTxnDateStr())
}

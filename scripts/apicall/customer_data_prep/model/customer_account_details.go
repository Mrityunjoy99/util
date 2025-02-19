package model

type CustomerAccountDetails struct {
	AccountNo           string  `json:"account_no"`
	AccountId           int     `json:"account_id"`
	CheckerClearBalance float64 `json:"checker_clear_balance"`
	AvailableBalance    float64 `json:"available_balance"`
	LatestTxnDate       string  `json:"txn_date"`
	ZeroBalance         bool    `json:"zero_balance"`
}

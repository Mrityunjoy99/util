package main

import (
	"fmt"

	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/db"
	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/helper"
	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/model"
	"gorm.io/gorm"
)

func getcustomerBalance(db *gorm.DB, accountId int) model.AccountBalance {
	// Get customer balance
	var accountBalance model.AccountBalance
	db.Model(&accountBalance).Where("account_id = ?", accountId).Limit(1).Scan(&accountBalance)
	return accountBalance
}

func enhanceCustomerData(db *gorm.DB) {
	csvWriter, err := helper.NewCSVWriter[model.CustomerAccountDetails]("/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/output/cl_1.csv")
	if err != nil {
		fmt.Println("Error creating CSV writer:", err)
		return
	}

	itr, err := helper.NewCSVIterator[model.CustomerAccount]("/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/input/cl_1.csv", 10)
	if err != nil {
		fmt.Println("Error creating CSV iterator:", err)
		return
	}

	for {
		chunk, ok := itr.Next()
		if !ok {
			break
		}
		for _, customer := range chunk {
			customerAccountDetails := getCustomerAccountDetails(db, customer)
			err := csvWriter.Write(customerAccountDetails)
			if err != nil {
				fmt.Println("Error writing to CSV:", err)
				return
			}
		}
	}
}

func getCustomerAccountDetails(db *gorm.DB, customer model.CustomerAccount) model.CustomerAccountDetails {
	// Get customer balance
	fmt.Println("Getting balance for account:", customer)
	balance := getcustomerBalance(db, customer.AccountId)
	return model.CustomerAccountDetails{
		AccountNo:           customer.AccountNo,
		AccountId:           customer.AccountId,
		CheckerClearBalance: balance.CheckerClearBalance,
		AvailableBalance:    balance.AvailableBalance,
		LatestTxnDate:       balance.LatestTxnDate,
		ZeroBalance:         balance.CheckerClearBalance == 0,
	}
}

func main() {
	db, err := db.GetDefaultDB()
	if err != nil {
		fmt.Println("Error connecting to database:", err)
		return
	}

	// Get customer balance
	// balance := getcustomerBalance(db, 11894518)
	// balance.Print()

	// Read customer data
	enhanceCustomerData(db)
}

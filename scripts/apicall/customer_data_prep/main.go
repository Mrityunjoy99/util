package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

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

func enhanceCustomerData(db *gorm.DB, ctx context.Context) {
	csvWriter, err := helper.NewCSVWriter[model.CustomerAccountDetails]("/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/output/customer_list.csv")
	if err != nil {
		fmt.Println("Error creating CSV writer:", err)
		return
	}

	itr, err := helper.NewCSVIterator[model.CustomerAccount]("/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/input/customer_list.csv", 10)
	if err != nil {
		fmt.Println("Error creating CSV iterator:", err)
		return
	}

	for {
		select {
		case <-ctx.Done():
			// Received termination signal, exit the loop
			fmt.Println("Received termination signal. Exiting the loop.")
			return
		default:
			chunk, ok := itr.Next()
			if !ok {
				break
			}

			wg := new(sync.WaitGroup)
			for _, customer := range chunk {
				wg.Add(1)
				go func(customer model.CustomerAccount) {
					defer wg.Done()
					customerAccountDetails := getCustomerAccountDetails(db, customer)
					err := csvWriter.Write(customerAccountDetails)
					if err != nil {
						fmt.Println("Error writing to CSV:", err)
						return
					}
				}(customer)
			}
			wg.Wait()
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
		LatestTxnDate:       balance.LatestTxnDate.Format("2006-01-02"),
		ZeroBalance:         balance.CheckerClearBalance == 0,
	}
}

func main() {
	// Set up signal catching
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel() // Ensure that cancel is called when main exits

	// Connect to the database
	db, err := db.GetDefaultDB()
	if err != nil {
		fmt.Println("Error connecting to database:", err)
		return
	}

	// Start enhancing customer data in a goroutine
	go enhanceCustomerData(db, ctx)

	// Wait for SIGTERM or SIGINT
	<-sigs

	// After receiving SIGTERM, wait for 5 seconds
	fmt.Println("Received termination signal. Waiting for 5 seconds...")
	cancel()
	time.Sleep(5 * time.Second)

	fmt.Println("Graceful shutdown complete.")
}

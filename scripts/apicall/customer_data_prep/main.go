package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/db"
	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/helper"
	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/metadata"
	"github.com/mrityunjoy99/util/scripts/apicall/customer_data_prep/model"
	"gorm.io/gorm"
)

func getcustomerBalance(db *gorm.DB, accountId int) (*model.AccountBalance, error) {
	// Get customer balance
	var accountBalance model.AccountBalance
	err := db.Model(&accountBalance).Where("account_id = ?", accountId).Limit(1).Scan(&accountBalance).Error
	if err != nil {
		return nil, fmt.Errorf("failed to get account balance: %w", err)
	}
	return &accountBalance, nil
}

func enhanceCustomerData(db *gorm.DB, ctx context.Context) {
	// Define file paths for input, output, and metadata (JSON file)
	inputFilePath := "/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/input/customer_list.csv"
	outputFilePath := "/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/output/customer_list.csv"
	failedFilePath := "/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/output/failed.csv"
	metadataFilePath := "/Users/mrityunjoydey/Documents/util/scripts/apicall/customer_data_prep/metadata/metadata.json"
	chenkSize := 200

	// Try to read the currentSeek from the metadata file
	var (
		currentSeek  int64 = 0
		csvWriter    *helper.CSVWriter[model.CustomerAccountDetails]
		failedWriter *helper.CSVWriter[model.CustomerAccount]
		err          error
	)
	if metadata, err := readMetadata(metadataFilePath); err == nil {
		// If metadata file exists and is valid, use the saved currentSeek
		currentSeek = metadata.CurrentSeek
	} else {
		// If reading the metadata file fails, we consider it as failure and start from the beginning
		fmt.Println("Error reading metadata file or invalid data, starting from the beginning.")
	}

	// Step 1: Start reading from the beginning if currentSeek is invalid
	if currentSeek == 0 {
		// Override the output file, start fresh from the beginning
		csvWriter, err = helper.NewCSVWriter[model.CustomerAccountDetails](outputFilePath, false)
		if err != nil {
			fmt.Println("Error creating CSV writer:", err)
			return
		}

		failedWriter, err = helper.NewCSVWriter[model.CustomerAccount](failedFilePath, false)
		if err != nil {
			fmt.Println("Error creating CSV writer:", err)
			return
		}
	} else {
		// Step 2: Read from the given seek, open the output file in append mode
		csvWriter, err = helper.NewCSVWriter[model.CustomerAccountDetails](outputFilePath, true)
		if err != nil {
			fmt.Println("Error creating CSV writer:", err)
			return
		}

		failedWriter, err = helper.NewCSVWriter[model.CustomerAccount](failedFilePath, true)
		if err != nil {
			fmt.Println("Error creating CSV writer:", err)
			return
		}
	}

	itr, err := helper.NewCSVIterator[model.CustomerAccount](inputFilePath, chenkSize, currentSeek)
	if err != nil {
		fmt.Println("Error creating CSV iterator:", err)
		return
	}

	// Process the input file and write to the output file
	processCSVChunks(ctx, db, itr, csvWriter, failedWriter, metadataFilePath)
}

// Helper function to process CSV chunks and handle termination signal
func processCSVChunks(
	ctx context.Context,
	db *gorm.DB,
	itr *helper.Iterator[model.CustomerAccount],
	csvWriter *helper.CSVWriter[model.CustomerAccountDetails],
	failedWriter *helper.CSVWriter[model.CustomerAccount],
	metadataFilePath string,
) {
	defer func() {
		err := saveMetadata(metadataFilePath, itr.GetCurrentRecord())
		if err != nil {
			fmt.Println("Error saving metadata:", err)
		}
	}()

	for {
		select {
		case <-ctx.Done():
			// Received termination signal, exit the loop and save current seek
			fmt.Println("Received termination signal. Saving current seek position.")
			return
		default:
			// Fetch a chunk from the iterator
			chunk, ok := itr.Next()
			if !ok {
				// No more data to process
				fmt.Println("No more data to process.")
				return
			}

			// Process the chunk in parallel
			wg := new(sync.WaitGroup)
			for _, customer := range chunk {
				wg.Add(1)
				go func(customer model.CustomerAccount) {
					defer wg.Done()
					// Get customer account details
					customerAccountDetails, err := getCustomerAccountDetails(db, customer)
					if err != nil {
						fmt.Println("Error getting customer account details:", err)
						failedWriter.Write(customer)
					} else {
						err = csvWriter.Write(*customerAccountDetails)
						if err != nil {
							fmt.Println("Error writing to CSV:", err)
						}
					}

				}(customer)
			}
			wg.Wait()
		}
	}
}

func saveMetadata(metadataFilePath string, currentSeek int64) error {
	// Save the current seek position to the metadata JSON file
	metadata := metadata.Metadata{
		CurrentSeek: currentSeek,
	}

	err := writeMetadata(metadataFilePath, metadata)
	if err != nil {
		return fmt.Errorf("failed to save current seek position: %w", err)
	}
	return nil
}

// Read the metadata from the JSON file
func readMetadata(metadataFilePath string) (metadata.Metadata, error) {
	var metadata metadata.Metadata
	file, err := os.Open(metadataFilePath)
	if err != nil {
		return metadata, err
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	err = decoder.Decode(&metadata)
	if err != nil {
		return metadata, fmt.Errorf("failed to decode metadata JSON: %w", err)
	}
	return metadata, nil
}

// Write the metadata to the JSON file
func writeMetadata(metadataFilePath string, metadata metadata.Metadata) error {
	file, err := os.Create(metadataFilePath)
	if err != nil {
		return fmt.Errorf("failed to create metadata file: %w", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ") // Pretty print JSON
	err = encoder.Encode(metadata)
	if err != nil {
		return fmt.Errorf("failed to encode metadata to JSON: %w", err)
	}
	return nil
}

func getCustomerAccountDetails(db *gorm.DB, customer model.CustomerAccount) (*model.CustomerAccountDetails, error) {
	// Get customer balance
	fmt.Println("Getting balance for account:", customer)
	balance, err := getcustomerBalance(db, customer.AccountId)
	if err != nil {
		return nil, fmt.Errorf("failed to get balance for account: %w", err)
	}

	return &model.CustomerAccountDetails{
		AccountNo:           customer.AccountNo,
		AccountId:           customer.AccountId,
		CheckerClearBalance: balance.CheckerClearBalance,
		AvailableBalance:    balance.AvailableBalance,
		LatestTxnDate:       balance.LatestTxnDate.Format("2006-01-02"),
		ZeroBalance:         balance.CheckerClearBalance == 0,
	}, nil
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

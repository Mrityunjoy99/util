package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"time"
)

const (
	RPS                          int           = 1
	TestDuration                 time.Duration = 5 * time.Second
	RequestPerAccountInTimeUnit1 int           = 1
	TimeUnit1                    time.Duration = 5 * time.Second
	BaseUrl                      string        = "https://api.uat-nebank.com/banking"
	Token                        string        = "NESFB_d2fa1ebe-6d99-4394-8841-309d02e081f0_NESFB-SLICE"
)

// Generate a random RRN (reversal reference number)
func generateRRN() int {
	// Seed the random number generator
	rand.NewSource(time.Now().UnixNano())
	// Generate a random RRN (8-digit number)
	return rand.Intn(99999999-10000000) + 10000000
}

func generateTransactionOrderId() int64 {
	// Seed the random number generator
	rand.NewSource(time.Now().UnixNano())
	// Generate a random 8 to 12 digit transaction order ID
	// Adjust the range to meet your requirements
	return rand.Int63n(899999999999) + 100000000000 // 12-digit random number
}

func constructRequest(rrn int, txnId int64, accountNumber string) http.Request {
	requestBody := fmt.Sprintf(`{
		"transactionOrderId": %d,
		"principalAccountNumber": "%s",
		"reversal": false,
		"transactionNature": "CREDIT",
		"amountInPaisa": "10000",
		"payerVpa": "9175264219@ybl",
		"payeeVpa": "9113764212@ybl",
		"remark": "BIS_test",
		"rrn": %d
	}`, txnId, accountNumber, rrn)

	req, err := http.NewRequest("POST", BaseUrl+"/bsgaccounting-api/v2/transfer/upi", bytes.NewBuffer([]byte(requestBody)))
	if err != nil {
		log.Printf("Error creating request: %v", err)
		return http.Request{}
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", Token)

	return *req
}

func getAccountNumber() string {
	return "50220000553464"
}

func execueOneRequest(client *http.Client) {
	rrn := generateRRN()
	txnId := generateTransactionOrderId()
	accountNumber := getAccountNumber()

	req := constructRequest(rrn, txnId, accountNumber)

	resp, err := client.Do(&req)
	if err != nil {
		log.Printf("Error executing request: %v", err)
		return
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Error reading response: %v", err)
		return
	}

	// Print the response status code and body
	fmt.Printf("Request txnId: %d, rrn: %d, Response Body: %s\n", txnId, rrn, string(body))
}

func main() {
	// Create an HTTP client
	client := &http.Client{}
	execueOneRequest(client)
}

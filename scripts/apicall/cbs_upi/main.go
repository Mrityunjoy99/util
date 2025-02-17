package main

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"net/http"
	"sync"
	"time"
)

// Generate a random RRN (reversal reference number)
func generateRRN() int {
	// Seed the random number generator
	rand.Seed(time.Now().UnixNano())
	// Generate a random RRN (8-digit number)
	return rand.Intn(99999999-10000000) + 10000000
}

func generateTransactionOrderId() int64 {
	// Seed the random number generator
	rand.Seed(time.Now().UnixNano())

	// Generate a random 8 to 12 digit transaction order ID
	// Adjust the range to meet your requirements
	return rand.Int63n(899999999999) + 100000000000 // 12-digit random number
}

// Function to make an HTTP request
func makeRequest(wg *sync.WaitGroup, client *http.Client, url string, header map[string]string) {
	defer wg.Done()

	// Generate a random RRN
	rrn := generateRRN()
	txnId := generateTransactionOrderId()

	// Create the request body with the generated RRN
	requestBody := fmt.Sprintf(`{
		"transactionOrderId": %d,
		"principalAccountNumber": "50220000553464",
		"reversal": false,
		"transactionNature": "CREDIT",
		"amountInPaisa": "10000",
		"payerVpa": "9175264219@ybl",
		"payeeVpa": "9113764212@ybl",
		"remark": "BIS_test",
		"rrn": %d
	}`, txnId, rrn)

	// Create the HTTP request
	req, err := http.NewRequest("POST", url, bytes.NewBuffer([]byte(requestBody)))
	if err != nil {
		log.Printf("Error creating request: %v", err)
		return
	}

	// Set headers
	for key, value := range header {
		req.Header.Set(key, value)
	}

	// Execute the request
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Error executing request: %v", err)
		return
	}
	defer resp.Body.Close()

	// Read the response body
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Error reading response: %v", err)
		return
	}

	// Print the response status code and body
	fmt.Printf("Request txnId: %d, rrn: %d, Response Body: %s\n", txnId, rrn, string(body))
}

func main() {
	// Define the URL and headers
	url := "http://localhost:9020/bsgaccounting-api/v2/transfer/upi"
	// url := "https://api.uat-nebank.com/banking/bsgaccounting-api/v2/transfer/upi"
	headers := map[string]string{
		"Content-Type":  "application/json",
		"Authorization": "NESFB_7be0ed97-f2fa-4666-b894-1f8c554b0a83_NESFB-SLICE",
	}

	// Create an HTTP client
	client := &http.Client{}

	// Define the number of concurrent requests you want to send
	numRequests := 10

	// Create a wait group to wait for all requests to finish
	var wg sync.WaitGroup

	// Fire the concurrent requests
	for i := 0; i < numRequests; i++ {
		wg.Add(1)
		go makeRequest(&wg, client, url, headers)
	}

	// Wait for all requests to complete
	wg.Wait()

	fmt.Println("All requests have been processed.")
}

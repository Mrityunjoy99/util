package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"

	"github.com/confluentinc/confluent-kafka-go/kafka"
)

func main() {
	// ! GIPL test casa
	// Define Kafka configuration
	config := &kafka.ConfigMap{
		"bootstrap.servers":  "pkc-371g2.ap-south-1.aws.confluent.cloud:9092",                    // Kafka broker address
		"sasl.mechanism":     "PLAIN",                                                            // SASL mechanism
		"security.protocol":  "SASL_SSL",                                                         // Use SASL with SSL encryption
		"sasl.username":      "KFKAUWX5IBUD6NP5",                                                 // Username
		"sasl.password":      "rtTLS+hqqDY3B/MgnJGoZJfKvLgRq3OeYVpfa120E52jQw38nly1ELWCpxUoZZLa", // Password
		"client.id":          "go-producer",                                                      // Client ID
		"acks":               "all",                                                              // Acknowledgment mode
		"enable.idempotence": true,                                                               // Enable idempotent producer
	}

	// ! Local Kafka
	// config := &kafka.ConfigMap{
	// 	"bootstrap.servers":  "localhost:9092", // Kafka broker address
	// 	"sasl.mechanism":     "PLAIN",          // SASL mechanism
	// 	"client.id":          "go-producer",    // Client ID
	// 	"acks":               "all",            // Acknowledgment mode
	// 	"enable.idempotence": true,             // Enable idempotent producer
	// }

	// Create Kafka producer
	producer, err := kafka.NewProducer(config)
	if err != nil {
		log.Fatalf("Failed to create producer: %s", err)
	}
	defer producer.Close()

	// Delivery report handler
	go func() {
		for e := range producer.Events() {
			switch ev := e.(type) {
			case *kafka.Message:
				if ev.TopicPartition.Error != nil {
					fmt.Printf("Failed to deliver message: %v\n", ev.TopicPartition)
				} else {
					fmt.Printf("Message delivered to %v\n", ev.TopicPartition)
				}
			}
		}
	}()

	// Topic to send message to
	// topic := "local-upi-post-txn"
	// topic := "gipl-upi-casa-details-test"
	// topic := "local-upi-switch-req"
	// topic := "local-non-slice-comms-events"
	topic := "gipl-cbs-txn-transformed-events-test"
	message := ReadJSONFile("event.json")
	// header := []kafka.Header{
	// 	{"srcTxnId", []byte("0193242d-b36e-7359-9b23-cd852ad5c4b4")},
	// 	{"x-slice-trace-id", []byte("SrcTxnId=0193242d-b36e-7359-9b23-cd852ad5c4b4")},
	// }
	header := []kafka.Header{
		{Key: "abc", Value: []byte("123")},
	}
	// Produce message to Kafka
	err = producer.Produce(&kafka.Message{
		TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
		Value:          []byte(message),
		Headers:        header,
	}, nil)

	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to produce message: %s\n", err)
	}

	// Wait for message deliveries before shutting down
	producer.Flush(15 * 1000)
}

func ReadJSONFile(filePath string) string {
	// Open the JSON file
	file, err := os.Open(filePath)
	if err != nil {
		panic(fmt.Errorf("failed to open file: %v", err))
	}
	defer file.Close()

	// Read the file contents
	byteValue, err := io.ReadAll(file)
	if err != nil {
		panic(fmt.Errorf("failed to read file: %v", err))
	}

	// Convert the byte slice to a map to ensure it's valid JSON
	var jsonData map[string]interface{}
	if err := json.Unmarshal(byteValue, &jsonData); err != nil {
		panic(fmt.Errorf("failed to unmarshal json: %v", err))
	}

	// Marshal it back to a string (pretty print)
	jsonString, err := json.MarshalIndent(jsonData, "", "  ")
	if err != nil {
		panic(fmt.Errorf("failed to marshal json: %v", err))
	}

	return string(jsonString)
}

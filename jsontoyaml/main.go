package main

import (
	"encoding/json"
	"fmt"
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"os"
)

type KeyValue struct {
	Name  string `yaml:"name"`
	Value string `yaml:"value"`
}

func jsonToYAML(inputJSON string) (string, error) {
	var data map[string]string
	err := json.Unmarshal([]byte(inputJSON), &data)
	if err != nil {
		return "", err
	}

	var result []KeyValue
	for key, value := range data {
		result = append(result, KeyValue{Name: key, Value: value})
	}

	yamlBytes, err := yaml.Marshal(result)
	if err != nil {
		return "", err
	}

	return string(yamlBytes), nil
}

func main() {
	// Read input from input.json
	inputJSON, err := ioutil.ReadFile("jsontoyaml/input.json")
	if err != nil {
		fmt.Println("Error reading input.json:", err)
		os.Exit(1)
	}

	// Convert JSON to YAML
	yamlResult, err := jsonToYAML(string(inputJSON))
	if err != nil {
		fmt.Println("Error:", err)
		os.Exit(1)
	}

	// Write output to output.yaml
	err = ioutil.WriteFile("jsontoyaml/output.yaml", []byte(yamlResult), 0644)
	if err != nil {
		fmt.Println("Error writing to output.yaml:", err)
		os.Exit(1)
	}

	fmt.Println("Conversion completed. Output written to output.yaml.")
}

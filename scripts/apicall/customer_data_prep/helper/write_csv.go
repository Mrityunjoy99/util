package helper

import (
	"encoding/csv"
	"errors"
	"fmt"
	"os"
	"reflect"
	"sync"
)

type CSVWriter[T any] struct {
	file       *os.File
	writer     *csv.Writer
	columns    []string
	columnsSet map[string]bool
	mutex      sync.Mutex
}

// NewCSVWriter initializes a new CSVWriter, creating or overwriting the file
func NewCSVWriter[T any](filename string) (*CSVWriter[T], error) {
	file, err := os.Create(filename)
	if err != nil {
		return nil, err
	}

	columns, err := extractHeaders[T]()
	if err != nil {
		return nil, err
	}

	writer := csv.NewWriter(file)
	if err := writer.Write(columns); err != nil {
		file.Close()
		return nil, err
	}

	return &CSVWriter[T]{
		file:       file,
		writer:     writer,
		columns:    columns,
		columnsSet: createColumnSet(columns),
	}, nil
}

// Write appends a new row to the CSV file, ensuring column consistency
func (cw *CSVWriter[T]) Write(obj T) error {
	cw.mutex.Lock()
	defer cw.mutex.Unlock()

	values, err := extractValues(obj, cw.columnsSet)
	if err != nil {
		return err
	}

	if err := cw.writer.Write(values); err != nil {
		return err
	}

	cw.writer.Flush()
	return nil
}

// Close closes the CSV file
func (cw *CSVWriter[T]) Close() error {
	cw.mutex.Lock()
	defer cw.mutex.Unlock()

	cw.writer.Flush()
	return cw.file.Close()
}

// extractHeaders extracts struct field names as CSV headers
func extractHeaders[T any]() ([]string, error) {
	var headers []string
	t := reflect.TypeOf((*T)(nil)).Elem() // Get type of T directly
	if t.Kind() != reflect.Struct {
		return nil, errors.New("type must be a struct")
	}

	for i := 0; i < t.NumField(); i++ {
		headers = append(headers, t.Field(i).Tag.Get("json"))
	}
	return headers, nil
}

// extractValues extracts struct values in order of headers
func extractValues[T any](obj T, expectedCols map[string]bool) ([]string, error) {
	v := reflect.ValueOf(obj)
	if v.Kind() != reflect.Struct {
		return nil, errors.New("input must be a struct")
	}

	var values []string
	for i := 0; i < v.Type().NumField(); i++ {
		fieldName := v.Type().Field(i).Tag.Get("json")
		if !expectedCols[fieldName] {
			return nil, errors.New("column inconsistency detected")
		}
		values = append(values, fmt.Sprint(v.Field(i)))
	}
	return values, nil
}

// createColumnSet creates a map for quick header validation
func createColumnSet(columns []string) map[string]bool {
	set := make(map[string]bool)
	for _, col := range columns {
		set[col] = true
	}
	return set
}
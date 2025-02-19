package helper

import (
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"reflect"
	"strconv"
)

type Iterator[T any] struct {
	reader        *csv.Reader
	file          *os.File
	headers       []string
	chunkSize     int
	currentRecord int64
}

func (it *Iterator[T]) GetCurrentRecord() int64 {
	return it.currentRecord
}

func NewCSVIterator[T any](filename string, chunkSize int, currentRecord int64) (*Iterator[T], error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("error opening file: %w", err)
	}

	reader := csv.NewReader(file)
	headers, err := reader.Read()
	if err != nil {
		file.Close()
		return nil, fmt.Errorf("error reading CSV header: %w", err)
	}

	// Skip records if currentRecord is not 0
	for i := int64(0); i < currentRecord; i++ {
		_, err := reader.Read() // Skip a record
		if err == io.EOF {
			file.Close()
			return nil, fmt.Errorf("EOF reached while skipping records")
		}
		if err != nil {
			file.Close()
			return nil, fmt.Errorf("error while skipping records: %w", err)
		}
	}

	return &Iterator[T]{
		reader:        reader,
		file:          file,
		headers:       headers,
		chunkSize:     chunkSize,
		currentRecord: currentRecord,
	}, nil
}

func (it *Iterator[T]) Next() ([]T, bool) {
	var chunk []T
	for i := 0; i < it.chunkSize; i++ {
		row, err := it.reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			fmt.Println("Error reading row:", err)
			break
		}
		if len(row) < len(it.headers) {
			continue
		}

		// Create a map for the row data
		objMap := make(map[string]interface{})
		for j, header := range it.headers {
			objMap[header] = row[j]
		}

		obj, err := convertTypes[T](objMap)
		if err != nil {
			fmt.Println("Error converting types:", err)
			continue
		}

		chunk = append(chunk, obj)
	}

	// Update the current record position in the iterator
	it.currentRecord += int64(len(chunk))

	if len(chunk) == 0 {
		it.file.Close()
		return nil, false
	}
	return chunk, true
}

func convertTypes[T any](objMap map[string]interface{}) (T, error) {
	var obj T
	v := reflect.ValueOf(&obj).Elem()
	t := v.Type()

	for i := 0; i < t.NumField(); i++ {
		field := v.Field(i)
		fieldName := t.Field(i).Tag.Get("json")

		// Retrieve value from the map
		value, exists := objMap[fieldName]
		if !exists {
			continue // Skip if the field is missing
		}

		// Perform type conversion based on the field type
		switch field.Kind() {
		case reflect.Int:
			if strVal, ok := value.(string); ok {
				intVal, err := strconv.Atoi(strVal)
				if err != nil {
					return obj, fmt.Errorf("could not convert '%s' to int: %w", strVal, err)
				}
				field.SetInt(int64(intVal))
			}
		case reflect.Float64:
			if strVal, ok := value.(string); ok {
				floatVal, err := strconv.ParseFloat(strVal, 64)
				if err != nil {
					return obj, fmt.Errorf("could not convert '%s' to float64: %w", strVal, err)
				}
				field.SetFloat(floatVal)
			}
		case reflect.Bool:
			if strVal, ok := value.(string); ok {
				boolVal, err := strconv.ParseBool(strVal)
				if err != nil {
					return obj, fmt.Errorf("could not convert '%s' to bool: %w", strVal, err)
				}
				field.SetBool(boolVal)
			}
		case reflect.String:
			if strVal, ok := value.(string); ok {
				field.SetString(strVal)
			}
		default:
			// Unsupported types are skipped
		}
	}

	return obj, nil
}

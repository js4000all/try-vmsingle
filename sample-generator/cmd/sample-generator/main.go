// sample-generator imitates a single PLC Reader collection cycle.
// It sends three gauge samples using OTLP/HTTP JSON, with no external Go dependencies.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

func attribute(key, value string) map[string]any {
	return map[string]any{"key": key, "value": map[string]any{"stringValue": value}}
}

func gauge(name string, value float64, timestamp string) map[string]any {
	return map[string]any{
		"name": name,
		"gauge": map[string]any{"dataPoints": []any{
			map[string]any{
				"attributes": []any{
					attribute("site_id", "site001"),
					attribute("device_id", "plc001"),
				},
				"timeUnixNano": timestamp,
				"asDouble": value,
			},
		}},
	}
}

func run() error {
	endpoint := os.Getenv("OTLP_METRICS_ENDPOINT")
	if endpoint == "" {
		endpoint = "http://otel-collector:4318/v1/metrics"
	}
	if !strings.HasPrefix(endpoint, "http://") && !strings.HasPrefix(endpoint, "https://") {
		return fmt.Errorf("OTLP_METRICS_ENDPOINT must be an HTTP URL")
	}

	timestamp := fmt.Sprintf("%d", time.Now().UnixNano())
	payload := map[string]any{
		"resourceMetrics": []any{
			map[string]any{
				"resource": map[string]any{
					"attributes": []any{attribute("service.name", "sample-generator")},
				},
				"scopeMetrics": []any{
					map[string]any{
						"scope": map[string]any{"name": "try-vmsingle/sample-generator"},
						"metrics": []any{
							gauge("plc_temperature_celsius", 23.5, timestamp),
							gauge("plc_pressure_mpa", 0.42, timestamp),
							gauge("plc_running", 1, timestamp),
						},
					},
				},
			},
		},
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("encode metrics: %w", err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("create request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("send OTLP metrics: %w", err)
	}
	defer resp.Body.Close()
	response, err := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if err != nil {
		return fmt.Errorf("read response: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("OTLP receiver returned %s: %s", resp.Status, strings.TrimSpace(string(response)))
	}
	fmt.Printf("OTLP request accepted (%s): 3 gauges at %s\n", resp.Status, timestamp)
	return nil
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

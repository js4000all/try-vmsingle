// sample-generator backfills four deterministic temperature series over UTC calendar months.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

const (
	metricName = "temperature_celsius"
	defaultEndpoint = "http://127.0.0.1:4318/v1/metrics"
)

type series struct {
	siteID   string
	sensorID string
}

var seriesList = []series{
	{"001", "1"}, {"001", "2"}, {"002", "1"}, {"002", "2"},
}

func attribute(key, value string) map[string]any {
	return map[string]any{"key": key, "value": map[string]any{"stringValue": value}}
}

// monthRange returns [start, end), with end rounded to the next minute
// after the latest permitted sample. The end is never beyond the next UTC month.
func monthRange(now time.Time, months int) (time.Time, time.Time, error) {
	if months < 1 {
		return time.Time{}, time.Time{}, errors.New("--months must be >= 1")
	}
	now = now.UTC()
	thisMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	start := thisMonth.AddDate(0, -(months - 1), 0)
	end := now.Truncate(time.Minute).Add(time.Minute)
	return start, end, nil
}

// valueFor is stable for a given series and UTC minute, independently of chunking.
func valueFor(s series, t time.Time) float64 {
	site, _ := strconv.Atoi(s.siteID)
	sensor, _ := strconv.Atoi(s.sensorID)
	days := float64(t.Unix()) / 86400
	return 18 + float64(site)*0.7 + float64(sensor)*1.2 +
		4*math.Sin(2*math.Pi*days/365.2425) +
		2*math.Sin(2*math.Pi*days)
}

func payloadFor(start, end time.Time) ([]byte, int, error) {
	metrics := make([]any, 0, 1)
	points := make([]any, 0, 4*int(end.Sub(start)/time.Minute))
	for t := start; t.Before(end); t = t.Add(time.Minute) {
		timestamp := strconv.FormatInt(t.UnixNano(), 10)
		for _, s := range seriesList {
			points = append(points, map[string]any{
				"attributes": []any{
					attribute("site_id", s.siteID),
					attribute("sensor_id", s.sensorID),
				},
				"timeUnixNano": timestamp,
				"asDouble": valueFor(s, t),
			})
		}
	}
	metrics = append(metrics, map[string]any{
		"name": metricName,
		"gauge": map[string]any{"dataPoints": points},
	})
	payload := map[string]any{"resourceMetrics": []any{
		map[string]any{
			"resource": map[string]any{
				"attributes": []any{attribute("service.name", "sample-generator")},
			},
			"scopeMetrics": []any{
				map[string]any{
					"scope": map[string]any{"name": "try-vmsingle/sample-generator"},
					"metrics": metrics,
				},
			},
		},
	}}
	data, err := json.Marshal(payload)
	return data, len(points), err
}

func send(client *http.Client, endpoint string, data []byte) error {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("create OTLP request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("send OTLP: %w", err)
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(io.LimitReader(resp.Body, 8192))
	if err != nil {
		return fmt.Errorf("read OTLP response: %w", err)
	}
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("collector returned %s: %s", resp.Status, strings.TrimSpace(string(body)))
	}
	// OTLP can report partial success with HTTP 200.
	var outcome struct {
		PartialSuccess struct {
			RejectedDataPoints int64  `json:"rejectedDataPoints,string"`
			ErrorMessage       string `json:"errorMessage"`
		} `json:"partialSuccess"`
	}
	if len(body) > 0 {
		if err := json.Unmarshal(body, &outcome); err != nil {
			return fmt.Errorf("decode OTLP response: %w", err)
		}
		if outcome.PartialSuccess.RejectedDataPoints != 0 || outcome.PartialSuccess.ErrorMessage != "" {
			return fmt.Errorf("collector partial success: rejected=%d message=%q",
				outcome.PartialSuccess.RejectedDataPoints, outcome.PartialSuccess.ErrorMessage)
		}
	}
	return nil
}

func run() error {
	months := flag.Int("months", 1, "Number of UTC calendar months, including current month")
	flag.Parse()
	if flag.NArg() != 0 {
		return fmt.Errorf("unexpected positional arguments: %v", flag.Args())
	}
	start, end, err := monthRange(time.Now(), *months)
	if err != nil {
		return err
	}
	endpoint := os.Getenv("OTLP_METRICS_ENDPOINT")
	if endpoint == "" {
		endpoint = defaultEndpoint
	}
	if !strings.HasPrefix(endpoint, "http://") && !strings.HasPrefix(endpoint, "https://") {
		return errors.New("OTLP_METRICS_ENDPOINT must be an HTTP(S) URL")
	}
	fmt.Printf("Generating 4 series in [%s, %s), UTC, 1 minute steps\n",
		start.Format(time.RFC3339), end.Format(time.RFC3339))
	client := &http.Client{Timeout: 60 * time.Second}
	total := 0
	for day := start; day.Before(end); day = day.AddDate(0, 0, 1) {
		dayEnd := day.AddDate(0, 0, 1)
		if dayEnd.After(end) {
			dayEnd = end
		}
		data, count, err := payloadFor(day, dayEnd)
		if err != nil {
			return fmt.Errorf("encode %s: %w", day.Format("2006-01-02"), err)
		}
		if err := send(client, endpoint, data); err != nil {
			return fmt.Errorf("send %s (%d samples): %w", day.Format("2006-01-02"), count, err)
		}
		total += count
		fmt.Printf("%s: accepted %d samples\n", day.Format("2006-01-02"), count)
	}
	fmt.Printf("Submitted %d samples to collector. Verify persistence via vmsingle export API.\n", total)
	return nil
}

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

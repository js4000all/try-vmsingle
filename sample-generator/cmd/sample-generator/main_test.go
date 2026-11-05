package main

import (
	"encoding/json"
	"testing"
	"time"
)

func TestMonthRange(t *testing.T) {
	now := time.Date(2026, 11, 5, 14, 15, 42, 0, time.UTC)
	cases := []struct {
		months int
		start  string
	}{
		{1, "2026-11-01T00:00:00Z"},
		{2, "2026-10-01T00:00:00Z"},
		{12, "2025-12-01T00:00:00Z"},
	}
	for _, tc := range cases {
		start, end, err := monthRange(now, tc.months)
		if err != nil {
			t.Fatal(err)
		}
		if got := start.Format(time.RFC3339); got != tc.start {
			t.Errorf("months=%d: start=%s, want %s", tc.months, got, tc.start)
		}
		if want := time.Date(2026, 11, 5, 14, 16, 0, 0, time.UTC); !end.Equal(want) {
			t.Errorf("end=%s, want=%s", end, want)
		}
	}
	if _, _, err := monthRange(now, 0); err == nil {
		t.Fatal("expected error for months=0")
	}
}

func TestDeterministicSamples(t *testing.T) {
	start := time.Date(2026, 11, 1, 0, 0, 0, 0, time.UTC)
	data, count, err := payloadFor(start, start.Add(2*time.Minute))
	if err != nil {
		t.Fatal(err)
	}
	if count != 8 {
		t.Fatalf("sample count=%d, want 8", count)
	}
	var result struct {
		ResourceMetrics []struct {
			ScopeMetrics []struct {
				Metrics []struct {
					Gauge struct {
						DataPoints []struct {
							TimeUnixNano string  `json:"timeUnixNano"`
							AsDouble     float64 `json:"asDouble"`
						} `json:"dataPoints"`
					} `json:"gauge"`
				} `json:"metrics"`
			} `json:"scopeMetrics"`
		} `json:"resourceMetrics"`
	}
	if err := json.Unmarshal(data, &result); err != nil {
		t.Fatal(err)
	}
	points := result.ResourceMetrics[0].ScopeMetrics[0].Metrics[0].Gauge.DataPoints
	if len(points) != 8 {
		t.Fatalf("data points=%d", len(points))
	}
	if points[0].TimeUnixNano != "1793491200000000000" {
		t.Errorf("unexpected UTC timestamp %s", points[0].TimeUnixNano)
	}
	if points[0].AsDouble != valueFor(seriesList[0], start) {
		t.Error("nondeterministic value")
	}
}

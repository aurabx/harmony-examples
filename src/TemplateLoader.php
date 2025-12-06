<?php

namespace Runbeam\HarmonyExamples;

use JsonException;
use RuntimeException;

class TemplateLoader
{
    /**
     * Load pipelines.json from project root.
     *
     * @return array
     * @throws RuntimeException|JsonException
     */
    public function loadPipelines(): array
    {
        return $this->loadJson(__DIR__ . '/../pipelines.json');
    }

    /**
     * Load transforms.json from project root.
     *
     * @return array
     * @throws RuntimeException|JsonException
     */
    public function loadTransforms(): array
    {
        return $this->loadJson(__DIR__ . '/../transforms.json');
    }

    /**
     * Load and decode a JSON file into an associative array.
     *
     * @param  string  $path  Path to JSON file
     * @return array
     * @throws RuntimeException|JsonException If file is missing, unreadable, or invalid JSON
     */
    private function loadJson(string $path): array
    {
        if (!is_file($path)) {
            throw new RuntimeException("File not found: {$path}");
        }

        $json = file_get_contents($path);
        if ($json === false) {
            throw new RuntimeException("Failed to read file: {$path}");
        }

        try {
            $data = json_decode($json, true, 512, JSON_THROW_ON_ERROR);
        } catch (JsonException $e) {
            throw new RuntimeException(
                "Failed to decode JSON in {$path}: " . $e->getMessage(),
                0,
                $e
            );
        }

        if (!is_array($data)) {
            throw new RuntimeException("Expected array in {$path}, got " . gettype($data));
        }

        return $data;
    }
}

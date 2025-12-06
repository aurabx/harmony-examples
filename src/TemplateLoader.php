<?php

namespace Runbeam\HarmonyExamples;

use RuntimeException;

class TemplateLoader
{
    /**
     * Load src/pipelines.json.
     *
     * @return array
     * @throws \JsonException
     */
    public function loadPipelines(): array
    {
        return $this->loadJson(__DIR__ . '/pipelines.json');
    }

    /**
     * Load src/transforms.json.
     *
     * @return array
     * @throws \JsonException
     */
    public function loadTransforms(): array
    {
        return $this->loadJson(__DIR__ . '/transforms.json');
    }

    /**
     * Load and decode a JSON file into an associative array.
     *
     * @param  string  $path  Path to JSON file
     * @return array
     * @throws RuntimeException|\JsonException If file is missing, unreadable, or invalid JSON
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

        $data = json_decode($json, true, 512, JSON_THROW_ON_ERROR);

        if (json_last_error() !== JSON_ERROR_NONE) {
            throw new RuntimeException(
                "Failed to decode JSON in {$path}: " . json_last_error_msg()
            );
        }

        if (!is_array($data)) {
            throw new RuntimeException("Expected array in {$path}, got " . gettype($data));
        }

        return $data;
    }
}

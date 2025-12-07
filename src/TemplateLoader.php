<?php

namespace Runbeam\HarmonyExamples;

use JsonException;
use RuntimeException;

class TemplateLoader
{
    /**
     * Load pipelines.json from project root.
     *
     * @param  string|null  $pipelines_root
     * @param  string|null  $pipelines_file
     * @return array
     * @throws JsonException
     */
    public function loadPipelines(string $pipelines_root = null, string $pipelines_file = null): array
    {
        $pipelines_root = $pipelines_root ?: __DIR__ . '/../';
        $pipelines_file = $pipelines_file ?: 'pipelines.json';

        return $this->loadJson($pipelines_root . $pipelines_file);
    }

    /**
     * Load transforms.json from project root.
     *
     * @param  string|null  $transforms_root
     * @param  string|null  $transforms_file
     * @return array
     * @throws JsonException
     */
    public function loadTransforms(string $transforms_root = null, string $transforms_file = null): array
    {
        $transforms_root = $transforms_root ?: __DIR__ . '/../';
        $transforms_file = $transforms_file ?: 'transforms.json';

        return $this->loadJson($transforms_root . $transforms_file);
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

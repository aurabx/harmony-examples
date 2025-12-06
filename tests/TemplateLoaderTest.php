<?php

namespace Runbeam\HarmonyExamples\Tests;

use PHPUnit\Framework\TestCase;
use Runbeam\HarmonyExamples\TemplateLoader;
use RuntimeException;

class TemplateLoaderTest extends TestCase
{
    private TemplateLoader $loader;

    protected function setUp(): void
    {
        $this->loader = new TemplateLoader();
    }

    public function testLoadPipelinesReturnsArray(): void
    {
        $pipelines = $this->loader->loadPipelines();

        $this->assertIsArray($pipelines);
        $this->assertNotEmpty($pipelines);
    }

    public function testLoadPipelinesContainsExpectedKeys(): void
    {
        $pipelines = $this->loader->loadPipelines();

        $this->assertArrayHasKey('basic-echo', $pipelines);
        $this->assertArrayHasKey('fhir', $pipelines);
        $this->assertArrayHasKey('dicom-scp', $pipelines);
    }

    public function testLoadPipelineItemsHaveRequiredFields(): void
    {
        $pipelines = $this->loader->loadPipelines();

        foreach ($pipelines as $key => $pipeline) {
            $this->assertArrayHasKey('name', $pipeline, "Pipeline '{$key}' missing 'name'");
            $this->assertArrayHasKey('description', $pipeline, "Pipeline '{$key}' missing 'description'");
            $this->assertArrayHasKey('categories', $pipeline, "Pipeline '{$key}' missing 'categories'");
            $this->assertArrayHasKey('file', $pipeline, "Pipeline '{$key}' missing 'file'");
            $this->assertArrayHasKey('type', $pipeline, "Pipeline '{$key}' missing 'type'");

            $this->assertIsArray($pipeline['categories'], "Pipeline '{$key}' categories should be array");
        }
    }

    public function testLoadPipelineCategoriesAreLowercase(): void
    {
        $pipelines = $this->loader->loadPipelines();

        foreach ($pipelines as $key => $pipeline) {
            foreach ($pipeline['categories'] as $category) {
                $this->assertEquals(
                    strtolower($category),
                    $category,
                    "Pipeline '{$key}' has non-lowercase category: '{$category}'"
                );
            }
        }
    }

    public function testLoadTransformsReturnsArrayOrFileNotFound(): void
    {
        try {
            $transforms = $this->loader->loadTransforms();
            $this->assertIsArray($transforms);
        } catch (\RuntimeException $e) {
            $this->assertStringContainsString('File not found:', $e->getMessage());
        }
    }

    public function testLoadJsonThrowsExceptionForMissingFile(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('File not found:');

        $reflection = new \ReflectionClass($this->loader);
        $method = $reflection->getMethod('loadJson');
        $method->setAccessible(true);
        $method->invoke($this->loader, '/non/existent/file.json');
    }

    public function testLoadJsonThrowsExceptionForInvalidJson(): void
    {
        $tempFile = tempnam(sys_get_temp_dir(), 'test');
        file_put_contents($tempFile, '{invalid json}');

        try {
            $reflection = new \ReflectionClass($this->loader);
            $method = $reflection->getMethod('loadJson');
            $method->setAccessible(true);

            try {
                $method->invoke($this->loader, $tempFile);
                $this->fail('Expected exception was not thrown');
            } catch (\RuntimeException $e) {
                $this->assertStringContainsString('Failed to decode JSON', $e->getMessage());
            }
        } finally {
            unlink($tempFile);
        }
    }

    public function testLoadJsonThrowsExceptionForNonArrayJson(): void
    {
        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('Expected array');

        $tempFile = tempnam(sys_get_temp_dir(), 'test');
        file_put_contents($tempFile, '"just a string"');

        try {
            $reflection = new \ReflectionClass($this->loader);
            $method = $reflection->getMethod('loadJson');
            $method->setAccessible(true);
            $method->invoke($this->loader, $tempFile);
        } finally {
            unlink($tempFile);
        }
    }
}

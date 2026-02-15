extends GutTest
## Phase 0: Sanity test to verify GUT is working correctly.

func test_true_is_true():
	assert_true(true, "true should be true")

func test_one_equals_one():
	assert_eq(1, 1, "1 should equal 1")

func test_string_not_empty():
	assert_ne("NovoJogo", "", "Game name should not be empty")

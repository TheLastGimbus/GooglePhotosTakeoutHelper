# Contributing

## Tests

Test data is quite large and lives in a separate repository. It is included into this one as
git submodule. The first time you want to run the tests you'll have to initialize the submodule
with

```bash
git submodule init
git submodule update
```

Run the integration tests by invoking in the project root

```bash
python3 -m unittest discover --failfast -s tests/integration
```

### Structure

- Integration tests are implemented in [`test_integration.py`](tests/integration/test_integration.py).
- For each test a folder named after the test case exists in [`fixtures/`](tests/integration/fixtures).
- Each folder contains the input data set in the `input/` subfolder and a reference of the expected output in the `reference/` subfolder.
- Each test case performs a full GooglePhotosTakeoutHelper run.
- Afterwords the generated output is compared to the reference.

### Adding a New Test Data Set

1. Create a new test case.
2. Create a data set folder in the `fixtures` folder named after the new test case.
3. Put the new data set inside a `input/` subfolder.
4. Run the tests. They will fail, but that is expected as no reference exists yet.
5. Take the output from [`workbench/output`](tests/integration/workbench/output) and copy it into the `reference/` subfolder of the new test data set.
6. Run the tests. They should pass now.
7. _Optional but highly recommended_:
  - Run `./clean_images.sh path/to/new/test/data/input`.
    - This removes the actual content from the images so you don't have to share your pictures publicly and shrinks them so they don't waste any space in the repo.
  - Run the tests again to verify the cleaning didn't mess anything up.
  - Copy `workbench/output` again to `reference` to use cleaned images there as well.
  - Run the tests again to verify everything is still working.
8. Commit the fixtures submodule.
9. Commit the new test together with the updated submodule reference.

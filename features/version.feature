Feature: The version command

  Scenario: The user wants to know the version of the CLI
    Given I have a working directory
    Then 'version' returns the right version
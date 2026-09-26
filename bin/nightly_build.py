#!/usr/bin/env -S uv run --script
"""
Python Regression Build Automation Script

This Python script serves the purpose of automating nightly regression builds for a software project.
The script is designed to handle the setup, execution, and reporting aspects of the regression testing process.

Features:

    1.  Nightly Regression Builds: The script is scheduled to run on a nightly basis, making and executing the regression builds.

    2.  Markdown Report Generation: Upon completion of the regression tests, the script generates detailed reports in Markdown format.
        These reports provide comprehensive insights into the test results, including test cases executed, pass/fail status, and any encountered issues.

    3.  Email Notification: The script is configured to send out email notifications summarizing the regression test results.
        These emails serve as communication channels for stakeholders, providing them with timely updates on the software's regression status.

Usage:
                    shutil.rmtree(file)

- The script is designed to be scheduled and executed automatically on a nightly basis using task scheduling tools such as Cronjobs. To create a cronjob do the following:
    1)  Open Terminal:

        Open your terminal application. This is where you'll enter the commands to create and manage cron jobs.

    2)  Access the Cron Table:

        Type the following command and press Enter:

        crontab -e

        This command opens the crontab file in your default text editor. If it's your first time, you might be prompted to choose a text editor.

    3)  Edit the Cron Table:
        The crontab file will open in your text editor. Each line in this file represents a cron job. You can now add your new cron job.

    4)  Syntax:

        Our cron job has the following syntax:
        0 3 * * * BASH_ENV=~/.bashrc bash -l -c "*WHERE YOUR CVW IS MUST PUT FULL PATH*/cvw/bin/wrapper_nightly_runs.sh > *WHERE YOU WANT TO STORE LOG FILES/cron.log 2>&1"

        This cronjob sources the .bashrc file and executes the wrapper script as a user.

    5)  Double check:

        Execute the following command to see your cronjobs:

        crontab -l

Dependencies:
    Python:
        - os
        - shutil
        - datetime from datetime
        - re
        - markdown
        - subprocess
        - argparse
        - logging

    Bash:
        - mutt (email sender)

Conclusion:

In summary, this Python script facilitates the automation of nightly regression builds, providing comprehensive reporting and email notification capabilities to ensure effective communication and monitoring of regression test results.
"""

import argparse
import logging
import os
import re
import shutil
import subprocess
import time
from datetime import datetime
from pathlib import Path

import markdown


class FolderManager:
    """A class for managing folders and repository cloning."""

    def __init__(self, basedir):
        """
        Initialize the FolderManager instance.

        Args:
            base_dir (str): The base directory where folders will be managed and repository will be cloned.
        """
        env_extract_var = "WALLY"
        if os.environ.get(env_extract_var):
            self.base_dir = os.environ.get(env_extract_var)
            self.base_parent_dir = os.path.dirname(self.base_dir)
        else:
            self.base_dir = basedir
            self.base_parent_dir = self.base_dir

        # logger.info(f"Base directory: {self.base_dir}")
        # logger.info(f"Parent Base directory: {self.base_parent_dir}")

    def create_folders(self, folders):
        """
        Create preliminary folders if they do not exist.

        Args:
            folders (list): A list of folder names to be created.

        Returns:
            None
        """

        for folder in folders:
            if not os.path.exists(folder):
                os.makedirs(folder)

    def remove_folder(self, folders):
        """
        Delete a folder, including all of its contents

        Args:
            folders (list): A folder to be deleted

        Returns:
            None
        """

        for folder in folders:
            if os.path.exists(folder):
                shutil.rmtree(folder)

    def remove_stale_folders(self, folder, days_old=30):
        """
        Delete all folders over X days old in a folder.

        Args:
            folder (str): Folder to delete folders and files from
            days_old (int): Number of days old a file must be before deleting

        Returns:
            None
        """
        dirs = os.listdir(folder)
        threshold = time.time() - days_old * 86400

        for file in dirs:
            file = os.path.join(folder, file)
            file_mtime = os.stat(file).st_mtime
            if file_mtime < threshold:
                if os.path.isfile(file):
                    os.remove(file)
                elif os.path.isdir(file):
                    shutil.rmtree(file)

    def clone_repository(self, folder, repo_url):
        """
        Clone a repository into the 'cvw' folder if it does not already exist.

        Args:
            repo_url (str): The URL of the repository to be cloned.

        Returns:
            None
        """
        cvw = folder.joinpath("cvw")
        tmp_folder = os.path.join(cvw, "tmp")  # temporary files will be stored in here
        if not cvw.exists():
            os.system(f"git clone --recurse-submodules {repo_url} {cvw}")
            os.makedirs(tmp_folder)

        # logger.info(f"Repository cloned: {repo_url}")


class TestRunner:
    """A class for making, running, and formatting test results."""

    def __init__(self, logger, log_dir):
        self.todays_date = datetime.now().strftime("%Y-%m-%d")
        self.current_datetime = datetime.now()
        self.logger = logger
        self.logger.info("Test runner object is initialized")
        self.log_dir = log_dir

    def copy_setup_script(self, folder):
        """
        Copy the setup script to the destination folder.

        The setup script will be copied from the base directory to a specific folder structure inside the base directory.

        Args:
            folder: the "nightly-runs/repos/"
            folder: the "nightly-runs/repos/"

        Returns:
            bool: True if the script is copied successfully, False otherwise.
        """
        # Get today's date in YYYY-MM-DD format
        self.todays_date = datetime.now().strftime("%Y-%m-%d")

        # Define the source and destination paths
        source_script = os.path.join(self.cvw, "setup_host.sh")
        destination_folder = os.path.join(self.base_parent_dir, folder, self.todays_date, "cvw")

        # Check if the source script exists
        if not os.path.exists(source_script):
            self.logger.error(f"Error: Source script '{source_script}' not found.")
            return False

        # Check if the destination folder exists, create it if necessary
        if not os.path.exists(destination_folder):
            self.logger.error(f"Error: Destination folder '{destination_folder}' not found.")
            return False

        # Copy the script to the destination folder
        try:
            shutil.copy(source_script, destination_folder)
            self.logger.info(f"Setup script copied to: {destination_folder}")
            return True
        except Exception as e:
            self.logger.error(f"Error copying setup script: {e}")
            return False

    def set_env_var(self, envar, value):
        """
        Set an environment variable to a value

        Args:
            envar (str): Environment variable to set
            value (str): New value for the environment variable

        Returns:
            None
        """
        self.logger.info(f"Setting {envar}={value}")
        os.environ[envar] = value

    def source_setup(self, folder):
        """
        Source a shell script.

        Args:
            script_path (str): Path to the script to be sourced.

        Returns:
            None
        """
        # find the new repository made
        cvw = folder.joinpath("cvw")
        self.logger.info(f"cvw is: {cvw}")

        self.cvw = cvw
        self.sim_dir = cvw.joinpath("bin")
        self.base_parent_dir = folder
        self.results_dir = folder.joinpath("results")

        self.logger.info(f"Tests are going to be ran from: {self.cvw}")

    def execute_makefile(self, makefile_path=None, target=None):
        """
        Execute a Makefile with optional target.

        Args:
            makefile_path (str): Path to the Makefile within the test repository
            target (str, optional): Target to execute in the Makefile.

        Returns:
            True if the tests were made
            False if the tests didnt pass
        """
        # Prepare the command to execute the Makefile
        makefile_location = self.cvw.joinpath(makefile_path)
        os.chdir(makefile_location)

        if target:
            output_file = self.log_dir.joinpath(f"make-{target}-output.log")
        else:
            output_file = self.log_dir.joinpath("make-output.log")

        # Source setup script and execute make with target and cores/2
        if target:
            command = [f"source {os.path.join(self.cvw, 'setup.sh')} > /dev/null && make {target} --jobs=$(($(nproc)/2))"]
        else:
            command = [f"source {os.path.join(self.cvw, 'setup.sh')} > /dev/null && make --jobs=$(($(nproc)/2))"]

        self.logger.info(f"Command used in directory {makefile_location}: {' '.join(command)}")

        # Execute the command using subprocess and save the output into a file
        with open(output_file, "w") as f:
            formatted_datetime = self.current_datetime.strftime("%Y-%m-%d %H:%M:%S")
            f.write(formatted_datetime)
            f.write("\n\n")
            result = subprocess.run(command, stdout=f, stderr=subprocess.STDOUT, text=True, shell=True, executable="/bin/bash")

        # Execute the command using a subprocess and not save the output
        # result = subprocess.run(command, text=True)

        # Check the result
        if result.returncode == 0:
            self.logger.info(f"Tests have been made with target: {' '.join(command)}")
            return True
        else:
            self.logger.error(f"Error making the tests. Command: {' '.join(command)}")
            return False

    def run_tests(self, test_type=None, test_name=None, test_extensions=None):
        """
        Run a script through the terminal and save the output to a file.

        Args:
            test_name (str): The test name will allow the function to know what test to execute in the sim directory
            test_type (str): The type such as python, bash, etc
        Returns:
            True and the output file location
        """

        # Prepare the function to execute the simulation

        output_file = self.log_dir.joinpath(f"{test_name}-output.log")
        os.chdir(self.sim_dir)

        # Source setup script and delete output from log on whatever test command gets run
        command = f"source {os.path.join(self.cvw, 'setup.sh')} > /dev/null && "

        if test_extensions:
            commandext = [test_type, test_name] + test_extensions
            self.logger.info(f"Command used to run tests in directory {self.sim_dir}: {test_type} {test_name} {' '.join(test_extensions)}")
        else:
            commandext = [test_type, test_name]
            self.logger.info(f"Command used to run tests in directory {self.sim_dir}: {test_type} {test_name}")
        command += " ".join(commandext)

        # Execute the command using subprocess and save the output into a file
        try:
            with open(output_file, "w") as f:
                formatted_datetime = self.current_datetime.strftime("%Y-%m-%d %H:%M:%S")
                f.write(formatted_datetime)
                f.write("\n\n")
                result = subprocess.run(command, stdout=f, stderr=subprocess.STDOUT, text=True, shell=True, executable="/bin/bash")
        except Exception as e:
            self.logger.error(f"There was an error in running the tests in the run_tests function: {e}")
        # Check if the command executed successfully
        if result.returncode or result.returncode == 0:
            self.logger.info(f"Test ran successfully. Test name: {test_name}, test extension: {' '.join(test_extensions)}")
            return True, output_file
        else:
            self.logger.error(f"Error making test. Test name: {test_name}, test extension: {' '.join(test_extensions)}")
            return False, output_file

    def copy_sim_logs(self, sim_log_folders):
        """
        Save script outputs from a directory back into the main log directory.

        Args:
            sim_log_folders (list): Locations to grab logs from. Will name new log folder the directory
            the log directory is in
        Returns:
            None
        """

        for sim_log_folder in sim_log_folders:
            try:
                log_folder_name = os.path.basename(sim_log_folder)
                self.logger.info(f"{log_folder_name}")
                sim_folder_name = os.path.basename(os.path.dirname(sim_log_folder))
                new_log_folder = self.log_dir / sim_folder_name
                self.logger.info(f"Copying {sim_log_folder} to {new_log_folder}")
                shutil.copytree(sim_log_folder, new_log_folder)
            except Exception as e:
                self.logger.error(f"There was an error copying simulation logs from {sim_log_folder} to {new_log_folder}: {e}")

    def clean_format_output(self, input_file, output_file=None):
        """
        Clean and format the output from tests.

        Args:
            input_file (str): Path to the input file with raw test results.
            output_file (str): Path to the file where cleaned and formatted output will be saved.

        Returns:
            None
        """
        # Implement cleaning and formatting logic here

        # Open up the file with only read permissions
        with open(input_file) as input_file:
            uncleaned_output = input_file.read()

        # use something like this function to detect pass and fail
        passed_configs = []
        failed_configs = []

        lines = uncleaned_output.split("\n")
        index = 0

        while index < len(lines):
            # Remove ANSI escape codes
            line = re.sub(r"\x1b\[[0-9;]*[mGK]", "", lines[index])

            if "Success" in line:  # test succeeds
                passed_configs.append(line.split(":")[0].strip())
            elif "passed lint" in line:
                passed_configs.append(f"Lint: {line.split(' ')[0].strip()}")
                # passed_configs.append(line) # potentially use a space
            elif "failed lint" in line:
                failed_configs.append([f"Lint: {line.split(' ')[0].strip()}", "No Log File"])
                # failed_configs.append(line)

            elif "Failures detected in output" in line:  # Text explicitly fails
                try:
                    config_name = line.split(":")[0].strip()
                    log_file = os.path.abspath(os.path.join("logs", config_name))
                    failed_configs.append((config_name, log_file))
                except:
                    failed_configs.append((config_name, "Log file not found"))

            elif "Timeout" in line:  # Test times out
                try:
                    config_name = line.split(":")[0].strip()
                    log_file = os.path.abspath("logs/" + config_name + ".log")
                    failed_configs.append((f"Timeout: {config_name}", log_file))
                except:
                    failed_configs.append((f"Timeout: {config_name}", "No Log File"))

            index += 1

        # alphabetically sort the configurations
        if len(passed_configs) != 0:
            passed_configs.sort()

        if len(failed_configs) != 0:
            failed_configs.sort()
        self.logger.info(f"Cleaned test results. Passed configs {passed_configs}. Failed configs: {failed_configs}")
        return passed_configs, failed_configs

    def rewrite_to_markdown(self, test_name, passed_configs, failed_configs):
        """
        Rewrite test results to markdown format.

        Args:
            input_file (str): Path to the input file with cleaned and formatted output.
            markdown_file (str): Path to the markdown file where test results will be saved.

        Returns:
            None
        """
        # Implement markdown rewriting logic here

        # output_directory = self.base_parent_dir.joinpath("results")
        os.chdir(self.results_dir)
        # current_directory = os.getcwd()
        output_file = os.path.join(self.results_dir, f"{test_name}.md")

        with open(output_file, "w") as md_file:
            # Title
            md_file.write(f"\n\n# Regression Test Results - {self.todays_date}\n\n")
            # md_file.write(f"\n\n<div class=\"regression\">\n# Regression Test Results - {timestamp}\n</div>\n\n")

            # File Path
            md_file.write(f"\n**File:** {output_file}\n\n")

            if failed_configs:
                md_file.write("## Failed Configurations\n\n")
                for config, log_file in failed_configs:
                    md_file.write(f'- <span class="failure" style="color: red;">{config}</span> ({log_file})\n')
                md_file.write("\n")
            else:
                md_file.write("## Failed Configurations\n")
                md_file.write("No Failures\n")

            md_file.write("\n## Passed Configurations\n")
            for config in passed_configs:
                md_file.write(f'- <span class="success" style="color: green;">{config}</span>\n')

        self.logger.info("writing test outputs to markdown")

    def combine_markdown_files(self, passed_tests, failed_tests, test_list, total_number_failures, total_number_success, test_type="default", markdown_file=None, args=None):
        """
        First we want to display the server properties like:
            - Server full name
            - Operating System

        Combine the markdown files and format them to display all of the failures at the top categorized by what kind of test it was
        Then display all of the successes.

        Args:
            passed_tests (list): a list of successful tests
            failed_tests (list): a list of failed tests
            test_list (list): a list of the test names.
            markdown_file (str): Path to the markdown file where test results will be saved.

        Returns:
            None
        """

        os.chdir(self.results_dir)
        output_file = self.results_dir.joinpath("results.md")

        with open(output_file, "w") as md_file:
            # Title
            md_file.write(f"\n\n# Nightly Test Results - {self.todays_date}\n\n")
            # Host information
            try:
                # Run hostname command
                hostname = subprocess.check_output(["hostname", "-A"]).strip().decode("utf-8")
                md_file.write(f"**Host name:** {hostname}")
                md_file.write("\n")
                # Run uname command to get OS information
                os_info = subprocess.check_output(["uname", "-a"]).strip().decode("utf-8")
                md_file.write(f"\n**Operating System Information:** {os_info}")
                md_file.write("\n")

                md_file.write(f"\n**Command used to execute test:** python nightly_build.py --path {args.path} --repository {args.repository} --target {args.target} --send_email {args.send_email}")
                md_file.write("\n")
            except subprocess.CalledProcessError as e:
                # Handle if the command fails
                md_file.write(f"Failed to identify host and Operating System information: {e!s}")

            # Which tests did we run
            md_file.write(f"\n**Tests made:** `make {test_type}`\n")

            # File Path
            md_file.write(f"\n**File:** {output_file}\n\n")  # *** needs to be changed
            md_file.write(f"**Total Successes: {total_number_success}**\n")
            md_file.write(f"**Total Failures: {total_number_failures}**\n")

            # Failed Tests
            md_file.write("\n\n## Failed Tests")
            md_file.write(f"\n**Total failed tests: {total_number_failures}**")
            for test_item, item in zip(test_list, failed_tests):
                md_file.write(f"\n\n### {test_item[1]} test")
                md_file.write(f"\n**Command used:** {test_item[0]} {test_item[1]} {' '.join(test_item[2])}\n\n")
                md_file.write("**Failed Tests:**\n")

                if len(item) == 0:
                    md_file.write("\n")
                    md_file.write('* <span class="no-failure" style="color: green;">No failures</span>\n')
                    md_file.write("\n")
                else:
                    for failed_test in item:
                        config = failed_test[0]
                        log_file = failed_test[1]

                        md_file.write("\n")
                        md_file.write(f'* <span class="failure" style="color: red;">{config}</span> ({log_file})\n')
                        md_file.write("\n")
            # Successful Tests

            md_file.write("\n\n## Successful Tests")
            md_file.write(f"\n**Total successful tests: {total_number_success}**")
            for test_item, item in zip(test_list, passed_tests):
                md_file.write(f"\n\n### {test_item[1]} test")
                md_file.write(f"\n**Command used:** {test_item[0]} {test_item[1]} {' '.join(test_item[2])}\n\n")
                md_file.write("\n**Successful Tests:**\n")

                if len(item) == 0:
                    md_file.write("\n")
                    md_file.write('* <span class="no-successes" style="color: red;">No successes</span>\n')
                    md_file.write("\n")
                else:
                    for passed_tests in item:
                        config = passed_tests

                        md_file.write("\n")
                        md_file.write(f'* <span class="success" style="color: green;">{config}</span>\n')
                        md_file.write("\n")

        self.logger.info("Combining markdown files")

    def convert_to_html(self, markdown_file="results.md", html_file="results.html"):
        """
        Convert markdown file to HTML.

        Args:
            markdown_file (str): Path to the markdown file.
            html_file (str): Path to the HTML file where converted output will be saved.

        Returns:
            None
        """
        # Implement markdown to HTML conversion logic here
        os.chdir(self.results_dir)

        with open(markdown_file) as md_file:
            md_content = md_file.read()
            html_content = markdown.markdown(md_content)

        with open(html_file, "w") as html_file:
            html_file.write(html_content)

        self.logger.info("Converting markdown file to html file.")

    def send_email(self, receiver_emails=None, subject="Nightly Regression Test"):
        """
        Send email with HTML content.

        !!! Requires mutt to be set up to send emails !!!

        Args:
            self: The instance of the class.
            sender_email (str): The sender's email address. Defaults to None.
            receiver_emails (list[str]): List of receiver email addresses. Defaults to None.
            subject (str, optional): Subject of the email. Defaults to "Nightly Regression Test".

        Returns:
            None
        """

        # check if there are any emails
        if not receiver_emails:
            self.logger.error("No receiver emails provided.")
            return

        # grab the html file
        os.chdir(self.results_dir)
        html_file = "results.html"

        with open(html_file) as html_file:
            body = html_file.read()

        try:
            for receiver_email in receiver_emails:
                # Compose the mutt command for each receiver email
                command = ["/usr/bin/mutt", "-s", subject, "-e", "set content_type=text/html", "--", receiver_email]
                try:
                    # Open a subprocess to run the mutt command
                    process = subprocess.Popen(command, stdin=subprocess.PIPE)
                    # Write the email body to the subprocess
                    process.communicate(body.encode("utf-8"))
                    self.logger.info(f"Sent email to {receiver_email}")
                except Exception as identifier:
                    self.logger.error(f"Error sending email with error: {identifier}")
        except Exception as identifier:
            self.logger.error(f"Error sending email with error: {identifier}")


def main():
    #############################################
    #                 ARG PARSER                #
    #############################################

    parser = argparse.ArgumentParser(description="Nightly Verification Testing for WALLY.")

    parser.add_argument("--path", default="nightly", help='specify the path for where the nightly repositories will be cloned ex: "nightly-runs')
    parser.add_argument("--repository", default="https://github.com/openhwgroup/cvw", help="specify which github repository you want to clone")
    parser.add_argument("--target", default="", help="types of tests you can make are: all, wally-riscv-arch-test, no")
    parser.add_argument("--tests", default="nightly", help="types of tests you can run are: nightly, test, test_lint")
    parser.add_argument("--send_email", default="", nargs="+", help='What emails to send test results to. Example: "[email1],[email2],..."')

    args = parser.parse_args()

    #############################################
    #                 SETUP                     #
    #############################################

    receiver_emails = args.send_email

    # file paths for where the results and repos will be saved: repos and results can be changed to whatever
    today = datetime.now().strftime("%Y-%m-%d")
    cvw_path = Path.home().joinpath(args.path, today)
    results_path = Path.home().joinpath(args.path, today, "results")
    log_path = Path.home().joinpath(args.path, today, "logs")
    log_file_path = log_path.joinpath("nightly_build.log")
    # creates the object
    folder_manager = FolderManager(basedir=args.path)

    # setting the path on where to clone new repositories of cvw
    folder_manager.create_folders([cvw_path, results_path, log_path])

    # clone the cvw repo
    folder_manager.clone_repository(cvw_path, args.repository)

    # Define tests that we can run
    #
    # flags are a list
    if args.tests == "all":
        test_list = [["python", "./regression-wally", ["--nightly", "--buildroot"]]]
    elif args.tests == "nightly":
        test_list = [["python", "./regression-wally", ["--nightly"]]]
    elif args.tests == "regression":
        test_list = [["python", "./regression-wally", []]]
    elif args.tests == "lint":
        test_list = [["python", "./lint-wally", ["--nightly"]]]
    else:
        print(f"Error: Invalid test {args.tests} specified")
        raise SystemExit

    #############################################
    #                 LOGGER                    #
    #############################################

    # Set up the logger
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.DEBUG)

    # Create a file handler
    # file_handler = logging.FileHandler('../../logs/nightly_build.log')

    file_handler = logging.FileHandler(log_file_path)
    file_handler.setLevel(logging.DEBUG)

    # Create a console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)

    # Create a formatter and add it to the handlers
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)

    # Add the handlers to the logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    logger.info(f"arg parser path: {args.path}")
    logger.info(f"arg parser repository: {args.repository}")
    logger.info(f"arg parser target: {args.target}")
    logger.info(f"arg parser send_email: {args.send_email}")
    logger.info(f"cvw path: {cvw_path}")
    logger.info(f"results path: {results_path}")
    logger.info(f"log folder path: {log_path}")
    logger.info(f"log file path: {log_file_path}")

    test_runner = TestRunner(logger, log_path)  # creates the object
    test_runner.source_setup(cvw_path)  # ensures that the new WALLY environmental variable is set correctly
    #############################################
    #              MAKE TESTS                   #
    #############################################

    if args.target != "no":
        test_runner.execute_makefile(target=args.target, makefile_path=test_runner.cvw)

    #############################################
    #               RUN TESTS                   #
    #############################################

    output_log_list = []  # a list where the output markdown file locations will be saved to
    total_number_failures = 0  # an integer where the total number failures from all of the tests will be collected
    total_number_success = 0  # an integer where the total number of successes will be collected

    total_failures = []
    total_success = []

    for test_type, test_name, test_extensions in test_list:
        check, output_location = test_runner.run_tests(test_type=test_type, test_name=test_name, test_extensions=test_extensions)
        try:
            if check:  # this checks if the test actually ran successfully
                output_log_list.append(output_location)
                logger.info(f"{test_name} ran successfully. Output location: {output_location}")
                # format tests to markdown
                try:
                    passed, failed = test_runner.clean_format_output(input_file=output_location)
                    logger.info(f"{test_name} has been formatted to markdown")
                except:
                    logger.error(f"Error occurred with formatting {test_name}")

                logger.info(f"The # of failures are for {test_name}: {len(failed)}")
                total_number_failures += len(failed)
                total_failures.append(failed)

                logger.info(f"The # of successes are for {test_name}: {len(passed)}")
                total_number_success += len(passed)
                total_success.append(passed)
                test_runner.rewrite_to_markdown(test_name, passed, failed)

                newlinechar = "\n"
                logger.info(f"Failed tests: \n{newlinechar.join([x[0] for x in failed])}")

        except Exception as e:
            logger.error(f"There was an error in running the tests: {e}")

    logger.info(f"The total successes for all tests ran are: {total_number_success}")
    logger.info(f"The total failures for all tests ran are: {total_number_failures}")

    # Copy actual test logs from sim/questa, sim/verilator, sim/vcs
    if args.tests != "test_lint":
        test_runner.copy_sim_logs([test_runner.cvw / "sim/questa/logs", test_runner.cvw / "sim/verilator/logs", test_runner.cvw / "sim/vcs/logs"])

    #############################################
    #               FORMAT TESTS                #
    #############################################

    # Combine multiple markdown files into one file
    try:
        test_runner.combine_markdown_files(
            passed_tests=total_success, failed_tests=total_failures, test_list=test_list, total_number_failures=total_number_failures, total_number_success=total_number_success, test_type=args.target, markdown_file=None, args=args
        )
    except Exception as e:
        logger.error(f"Error combining the markdown tests called from main: {e}")

    #############################################
    #             WRITE MD TESTS                #
    #############################################
    test_runner.convert_to_html()

    #############################################
    #                SEND EMAIL                 #
    #############################################

    if receiver_emails:
        test_runner.send_email(receiver_emails=receiver_emails)

    #############################################
    #   DELETE REPOSITORY OF PREVIOUS NIGHTLYS  #
    #############################################
    threshold = time.time() - 86400 * 7  # 1 week

    for log_dir in os.listdir(args.path):
        try:
            cvw_dir = os.path.join(args.path, log_dir, "cvw")
            cvw_mtime = os.stat(cvw_dir).st_mtime
            if cvw_mtime < threshold:
                logger.info(f"Found {cvw_dir} older than 1 week, removing")
                shutil.rmtree(cvw_dir)
        except Exception as e:
            if os.path.exists(cvw_dir):
                logger.info(f"ERROR: Failed to remove previous nightly run repo with error {e}")

    #############################################
    #      DELETE STALE LOGS AFTER TESTING      #
    #############################################
    folder_manager.remove_stale_folders(folder=args.path, days_old=30)


if __name__ == "__main__":
    main()

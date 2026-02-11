#!/usr/bin/python3
import subprocess
from typing import List
from sp_shared.log import get_log


def get_trimmed_nonempty_lines(in_multiline_str: str) -> List[str]:
    """
    Given an input string which may be multiline, return a list of strings
    which are all the lines in the input.

    Leading and trailing whitespace are removed from each line returned.
    Any line which was empty or entirely whitespace is not returned.
    """
    return [line.strip() for line in in_multiline_str.split("\n") if line.strip()]


def run_shell_command_and_get_output(command: List[str]) -> List[str]:
    """
    Run the supplied command (as a list of args) and return its output as a list
    of trimmed, non‑empty lines.

    Resource‑safe behavior:
    - No shell is used (avoids shell injection).
    - A timeout is applied so the subprocess cannot run indefinitely.
    """
    try:
        command_return = subprocess.check_output(
            command,
            stderr=subprocess.STDOUT,
            text=True,      # returns str directly
            timeout=30,     # seconds; adjust for your environment
        )
    except subprocess.TimeoutExpired as ex:
        fail_msg = (
            f"Command timed out after {ex.timeout} seconds: {command}"
        )
        get_log().warning(fail_msg)
        return []
    except subprocess.CalledProcessError as ex:
        # Non‑zero exit status; capture output for diagnosis
        fail_msg = (
            f"Command failed with return code {ex.returncode}: {command}"
        )
        get_log().warning(fail_msg)
        if ex.output:
            get_log().warning(ex.output)
        return get_trimmed_nonempty_lines((ex.output or ""))
    except Exception as ex:
        # Unexpected failure; log and re‑raise or return empty list,
        # depending on how callers are expected to behave.
        fail_msg = (
            f"Encountered unexpected exception running command {command}: {type(ex)}: {ex}"
        )
        get_log().warning(fail_msg)
        return []

    return get_trimmed_nonempty_lines(command_return)

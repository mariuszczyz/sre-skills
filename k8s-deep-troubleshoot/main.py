#!/usr/bin/env python3
"""
Kubernetes Deep Troubleshooting Skill Wrapper

This is the skill entry point that invokes the kubectl-based troubleshooting script.
Used by Claude Code when invoking /k8s-troubleshoot command.
"""

import subprocess
import sys
from pathlib import Path


def run_troubleshoot(args: list[str]) -> str:
    """Run the troubleshoot script with given arguments"""
    script_path = Path(__file__).parent / "k8s-troubleshoot.sh"

    if not script_path.exists():
        return f"[ERROR] Troubleshoot script not found at {script_path}"

    try:
        result = subprocess.run(
            ["bash", str(script_path)] + args,
            capture_output=True,
            text=True,
            timeout=120
        )

        output = result.stdout
        if result.stderr:
            # Filter out verbose debug output if not in debug mode
            for line in result.stderr.splitlines():
                if not line.startswith("[DEBUG]"):
                    output += f"\n{line}"

        return output

    except subprocess.TimeoutExpired:
        return "[ERROR] Troubleshooting timed out after 120 seconds"
    except Exception as e:
        return f"[ERROR] Failed to run troubleshoot: {e}"


def main():
    """Main entry point for the skill"""
    if len(sys.argv) < 2:
        # Run with no args to show help
        output = run_troubleshoot([])
        print(output)
        return

    command = sys.argv[1]
    args = sys.argv[2:]

    if command == "help" or command in ["-h", "--help"]:
        output = run_troubleshoot(["help"])
    else:
        output = run_troubleshoot([command] + args)

    print(output)


if __name__ == "__main__":
    main()

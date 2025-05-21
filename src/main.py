from __future__ import annotations

import sys
import base64
import json

from typing import Any

from google.api_core.extended_operation import ExtendedOperation
from google.cloud import compute_v1

TERMINATED = compute_v1.Instance.Status.TERMINATED.name
RUNNING = compute_v1.Instance.Status.RUNNING.name


def wait_for_extended_operation(
    operation: ExtendedOperation, verbose_name: str = "operation", timeout: int = 300
) -> Any:
    """
    Waits for the extended (long-running) operation to complete.

    If the operation is successful, it will return its result.
    If the operation ends with an error, an exception will be raised.
    If there were any warnings during the execution of the operation
    they will be printed to sys.stderr.

    Args:
        operation: a long-running operation you want to wait on.
        verbose_name: (optional) a more verbose name of the operation,
            used only during error and warning reporting.
        timeout: how long (in seconds) to wait for operation to finish.
            If None, wait indefinitely.

    Returns:
        Whatever the operation.result() returns.

    Raises:
        This method will raise the exception received from operation.exception()
        or RuntimeError if there is no exception set, but there is an error_code
        set for the operation.

        In case of an operation taking longer than timeout seconds to complete,
        a concurrent.futures.TimeoutError will be raised.
    """
    result = operation.result(timeout=timeout)

    if operation.error_code:
        print(
            f"[ERROR] {verbose_name}: [Code: {operation.error_code}]: {operation.error_message}",
            flush=True,
        )
        raise operation.exception() or RuntimeError(operation.error_message)

    if operation.warnings:
        print(f"[WARNING] {verbose_name} produced warnings:", flush=True)
        for warning in operation.warnings:
            print(f" - {warning.code}: {warning.message}", flush=True)

    print(f"[INFO] {verbose_name} completed successfully", flush=True)
    return result


def get_instance(project_id: str, zone: str, instance_name: str) -> compute_v1.Instance:
    """
    Gets a Google Compute Engine instance.

    Args:
        project_id: project ID or project number of the Cloud project your instance belongs to.
        zone: name of the zone your instance belongs to.
        instance_name: name of the instance you want to get.

    Returns:
        The instance object.
    """
    client = compute_v1.InstancesClient()
    return client.get(
        project=project_id, zone=zone, instance=instance_name, timeout=300
    )


def stop_instance_if_needed(project_id: str, zone: str, instance_name: str) -> None:
    """
    Stops a running Google Compute Engine instance if it is running.
    Args:
        project_id: project ID or project number of the Cloud project your instance belongs to.
        zone: name of the zone your instance belongs to.
        instance_name: name of the instance your want to stop.
    """

    client = compute_v1.InstancesClient()
    instance = get_instance(project_id, zone, instance_name)

    if instance.status == TERMINATED:
        print(
            f"[INFO] Instance {instance.name}  is already in TERMINATED state.",
            flush=True,
        )
        return

    print(f"[INFO] Stopping instance {instance.name}...", flush=True)
    operation = client.stop(project=project_id, zone=zone, instance=instance_name)
    wait_for_extended_operation(operation, "Stopping instance")


def change_machine_type_if_needed(
    project_id: str, zone: str, instance_name: str, new_machine_type: str
) -> None:
    """
    Changes the machine type of VM. The VM needs to be in the 'TERMINATED' state for this operation to be successful.

    Args:
        project_id: project ID or project number of the Cloud project you want to use.
        zone: name of the zone your instance belongs to.
        instance_name: name of the VM you want to modify.
        new_machine_type: the new machine type you want to use for the VM.
            More about machine types: https://cloud.google.com/compute/docs/machine-resource
    """

    client = compute_v1.InstancesClient()
    instance = get_instance(project_id, zone, instance_name)
    current_machine_type = instance.machine_type.split("/")[-1]

    if current_machine_type == new_machine_type:
        if instance.status == RUNNING:
            print(
                f"[INFO] Instance {instance.name} is already of type {new_machine_type} and is running. Skipping update.",
                flush=True,
            )
            return
        else:
            print(
                f"[INFO] Instance {instance.name} is already of type {new_machine_type} and stopped. Starting the server.",
                flush=True,
            )
            start_operation = client.start(
                project=project_id, zone=zone, instance=instance_name
            )
            wait_for_extended_operation(start_operation, "Starting instance")
            return

    if instance.status == RUNNING:
        print(
            f"[WARNING] Instance {instance.name} is RUNNING. It must be stopped to change machine type.",
            flush=True,
        )
        stop_instance_if_needed(project_id, zone, instance_name)
        instance = get_instance(project_id, zone, instance_name)

    print(
        f"[INFO] Changing machine type of {instance.name} to {new_machine_type}...",
        flush=True,
    )

    machine_type = compute_v1.InstancesSetMachineTypeRequest()
    machine_type.machine_type = (
        f"projects/{project_id}/zones/{zone}/machineTypes/{new_machine_type}"
    )

    operation = client.set_machine_type(
        project=project_id,
        zone=zone,
        instance=instance_name,
        instances_set_machine_type_request_resource=machine_type,
    )
    wait_for_extended_operation(operation, "Changing machine type")

    print(
        f"[INFO] Restarting instance {instance.name} after machine type update...",
        flush=True,
    )
    start_operation = client.start(
        project=project_id, zone=zone, instance=instance_name
    )
    wait_for_extended_operation(start_operation, "Starting instance")
    print(
        f"[INFO] Instance {instance.name} machine type changed from {current_machine_type} to {new_machine_type}, and is successfully restarted.",
        flush=True,
    )


def pubsub_handler(event: dict, context) -> None:
    """
    Cloud Function entry point for Pub/Sub-triggered VM resize operation.
    Expects JSON payload with: project_id, zone, instance_name, new_machine_type
    """
    try:
        message_data = base64.b64decode(event["data"]).decode("utf-8")
        payload = json.loads(message_data)

        project_id = payload["project_id"]
        zone = payload["zone"]
        instance_name = payload["instance_name"]
        new_machine_type = payload["new_machine_type"]

        stop_instance_if_needed(project_id, zone, instance_name)
        change_machine_type_if_needed(project_id, zone, instance_name, new_machine_type)

    except KeyError as e:
        print(
            f"[ERROR] Missing required payload field: {e}", file=sys.stderr, flush=True
        )
    except json.JSONDecodeError:
        print("[ERROR] Invalid JSON in Pub/Sub message.", file=sys.stderr, flush=True)
    except Exception as e:
        print(f"[ERROR] Unexpected error: {str(e)}", file=sys.stderr, flush=True)
        raise


# if __name__ == "__main__":
#     # This is a placeholder for local testing.
#     # You can add code here to test the functions locally if needed.

#     change_machine_type_if_needed(
#         project_id="682348490962",
#         zone="us-central1-f",
#         instance_name="tf-jessica-vm-delete",
#         new_machine_type="e2-small",
#     )

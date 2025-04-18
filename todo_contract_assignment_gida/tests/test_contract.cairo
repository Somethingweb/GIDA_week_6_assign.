use todo::todo::{TodoList, ITodoListDispatcher, ITodoListSafeDispatcher, ITodoListSafeDispatcherTrait, ITodoListDispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, declare,
    start_cheat_caller_address, stop_cheat_caller_address,
};
use starknet::ContractAddress;

pub fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}
pub fn OSCAR() -> ContractAddress {
    'OSCAR'.try_into().unwrap()
}

fn deploy_contract() -> ContractAddress {
    let class_hash = declare("TodoList").unwrap().contract_class();
    let mut calldata = array![];
    OWNER().serialize(ref calldata);
    let (contract_address, _) = class_hash.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_add_task_as_owner() {
    let contract_address = deploy_contract();
    let todo = ITodoListDispatcher { contract_address };
    start_cheat_caller_address(contract_address, OWNER());
    let task_id = todo.add_task('Complete your assignment');
    stop_cheat_caller_address(contract_address);
    assert!(task_id == 1, "Expected task ID to be 1");
}

#[test]
#[feature("safe_dispatcher")]
fn test_add_task_unauthorized() {
    let contract_address = deploy_contract();
    let todo = ITodoListSafeDispatcher { contract_address };
    start_cheat_caller_address(contract_address, OSCAR());
    let result = todo.add_task('Unauthorized task');
    stop_cheat_caller_address(contract_address);
    assert!(result.is_err(), "Non-owner should not be able to add a task");
}

#[test]
fn test_complete_task_success() {
    let contract_address = deploy_contract();
    let todo = ITodoListDispatcher { contract_address };
    start_cheat_caller_address(contract_address, OWNER());
    let task_id = todo.add_task('Complete your recent task');
    todo.complete_task(task_id);
    stop_cheat_caller_address(contract_address);
}

#[test]
fn test_delete_task_success() {
    let contract_address = deploy_contract();
    let todo = ITodoListDispatcher { contract_address };
    start_cheat_caller_address(contract_address, OWNER());
    let task_id = todo.add_task('Delete your last work');
    todo.delete_task(task_id);
    stop_cheat_caller_address(contract_address);
}

#[test]
#[feature("safe_dispatcher")]
fn test_delete_task_unauthorized() {
    let contract_address = deploy_contract();
    let todo = ITodoListSafeDispatcher { contract_address };
    start_cheat_caller_address(contract_address, OWNER());
    let task_id_result = todo.add_task('Schedule weekend workout task');
    assert!(task_id_result.is_ok(), "Task creation by owner should succeed");
    let task_id = task_id_result.unwrap();
    stop_cheat_caller_address(contract_address);

    start_cheat_caller_address(contract_address, OSCAR());
    let result = todo.delete_task(task_id);
    stop_cheat_caller_address(contract_address);
    assert!(result.is_err(), "Unauthorized user should not delete task");
}

#[test]
fn test_get_all_tasks_ignores_deleted() {
    let contract_address = deploy_contract();
    let todo = ITodoListDispatcher { contract_address };
    start_cheat_caller_address(contract_address, OWNER());
    todo.add_task('Keep this');
    todo.add_task('Delete this');
    todo.delete_task(2);
    let tasks = todo.get_all_tasks();
    stop_cheat_caller_address(contract_address);
    assert!(tasks.len() == 1, "Only 1 active task should remain");
}
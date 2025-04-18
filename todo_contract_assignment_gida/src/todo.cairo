#[derive(Copy, Drop, starknet::Store, Serde, PartialEq)]
pub struct Task {
    id: u64,
    title: felt252,
    completed: bool,
}

#[starknet::interface]
pub trait ITodoList<TContractState> {
    fn add_task(ref self: TContractState, title: felt252) -> u64;
    fn complete_task(ref self: TContractState, task_id: u64);
    fn delete_task(ref self: TContractState, task_id: u64);
    fn get_all_tasks(self: @TContractState) -> Array<Task>;
}

#[starknet::contract]
pub mod TodoList {
use starknet::ContractAddress;
    use starknet::get_caller_address;
    use starknet::event::EventEmitter;
    use core::starknet::storage::{
        Map, StoragePointerReadAccess, StoragePointerWriteAccess,StorageMapWriteAccess, StorageMapReadAccess,
    };
    
    use super::{Task, ITodoList};

    #[storage]
    struct Storage {
        tasks: Map<u64, Task>,
        taskCount: u64,
        owner: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        TaskAdded: TaskAdded,
        TaskCompleted: TaskCompleted,
        TaskDeleted: TaskDeleted,
    }

    #[derive(Drop, starknet::Event)]
    struct TaskAdded {
        task_id: u64,
        title: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct TaskCompleted {
        task_id: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct TaskDeleted {
        task_id: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner_address: ContractAddress) {
        self.owner.write(owner_address);
        self.taskCount.write(0); 
    }


    #[abi(embed_v0)]
    impl TodoListImpl of ITodoList<ContractState> {
        fn add_task(ref self: ContractState, title: felt252) -> u64 {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Only owner can add tasks');
            
            let task_id = self.taskCount.read() + 1;
            assert(title != 0, 'Task title cannot be empty');
            let newTask = Task { id: task_id, title, completed: false };

            self.tasks.write(task_id, newTask);
            self.taskCount.write(task_id);
            self.emit(TaskAdded { task_id, title });
            task_id
        }

        fn complete_task(ref self: ContractState, task_id: u64) {
         
            let caller = get_caller_address();
            let owner = self.owner.read();
          
            assert(caller == owner, 'Only owner can complete tasks');
            let mut task = self.tasks.read(task_id);
            assert(task.id == task_id, 'Task does not exist');
            assert(task.completed == false, 'Task already completed');
            
            task.completed = true;
            self.tasks.write(task_id, task);
            
            self.emit(TaskCompleted { task_id });
        }
        

        fn delete_task(ref self: ContractState, task_id: u64) {
            let caller = get_caller_address();
            assert(self.owner.read() == caller, 'Unauthorized');
            let task = self.tasks.read(task_id);
            assert(task.id == task_id, 'Task does not exist');
        
            let blank_task = Task {
                id: 0,
                title: 0,
                completed: false,
            };
            self.tasks.write(task_id, blank_task);
            self.emit(TaskDeleted { task_id });
        }

        fn get_all_tasks(self: @ContractState) -> Array<Task> {
            let mut all_tasks = ArrayTrait::new();
            let tasks_count = self.taskCount.read();
            
            let mut i: u64 = 1;
            while i <= tasks_count {
                let task = self.tasks.read(i);
                if task.id != 0 { 
                    all_tasks.append(task);
                }
                i += 1;
            };
            
            all_tasks
        }
        }

    }
    

[manualfree] module userland

import fs
import memory
import elf
import sched
import file
import proc
import x86.cpu.local as cpulocal

pub fn syscall_fork(gpr_state &cpulocal.GPRState) (u64, u64) {
	old_thread := proc.current_thread()
	mut old_process := old_thread.process

	mut new_process := sched.new_process(old_process, voidptr(0)) or {
		panic('fork failure')
	}

	stack_size := u64(65536)

	mut new_thread := &proc.Thread{
		gpr_state: gpr_state
		process: new_process
		timeslice: old_thread.timeslice
		gs_base: old_thread.gs_base
		fs_base: old_thread.fs_base
		kernel_stack: u64(memory.pmm_alloc(stack_size / page_size)) + stack_size + higher_half
		pf_stack: u64(memory.pmm_alloc(stack_size / page_size)) + stack_size + higher_half
		running_on: u64(-1)
		cr3: u64(new_process.pagemap.top_level)
	}

	new_thread.gpr_state.rax = u64(0)
	new_thread.gpr_state.r8 = u64(0)

	old_process.children << new_process
	new_process.threads << new_thread

	sched.enqueue_thread(new_thread)

	return u64(new_process.pid), u64(0)
}

pub fn start_program(execve bool, path string, argv []string, envp []string,
					 stdin string, stdout string, stderr string) ?&proc.Process {
	prog_node := fs.get_node(vfs_root, path) or {
		return error('Program not found')
	}
	prog := prog_node.resource

	mut new_pagemap := memory.new_pagemap()

	auxval, ld_path := elf.load(new_pagemap, prog, 0) or {
		return error('elf load failed')
	}

	mut entry_point := voidptr(0)

	if ld_path == '' {
		entry_point = voidptr(auxval.at_entry)
	} else {
		ld_node := fs.get_node(vfs_root, ld_path) or {
			return error('Program interpreter not found')
		}
		ld := ld_node.resource

		ld_auxval, _ := elf.load(new_pagemap, ld, 0x40000000) or {
			return error('elf load (ld) failed')
		}

		entry_point = voidptr(ld_auxval.at_entry)
	}

	mut new_process := &proc.Process(0)

	if execve == false {
		new_process = sched.new_process(voidptr(0), new_pagemap) or {
			return none
		}

		stdin_node := fs.get_node(vfs_root, stdin) or {
			return error('stdin not found')
		}
		stdin_handle := &file.Handle{resource: stdin_node.resource
									 node: stdin_node
									 refcount: 1}
		stdin_fd := &file.FD{handle: stdin_handle}
		new_process.fds[0] = voidptr(stdin_fd)

		stdout_node := fs.get_node(vfs_root, stdout) or {
			return error('stdout not found')
		}
		stdout_handle := &file.Handle{resource: stdout_node.resource
									  node: stdout_node
									  refcount: 1}
		stdout_fd := &file.FD{handle: stdout_handle}
		new_process.fds[1] = voidptr(stdout_fd)

		stderr_node := fs.get_node(vfs_root, stderr) or {
			return error('stderr not found')
		}
		stderr_handle := &file.Handle{resource: stderr_node.resource
									  node: stderr_node
									  refcount: 1}
		stderr_fd := &file.FD{handle: stderr_handle}
		new_process.fds[2] = voidptr(stderr_fd)

		sched.new_user_thread(new_process, true,
							  entry_point, voidptr(0),
							  argv, envp, auxval, true) or {
			return none
		}
	} else {
		panic('TODO: execve')
	}

	return new_process
}

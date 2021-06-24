[manualfree] module klock

import katomic
import trace

pub struct Lock {
pub mut:
	l bool
	caller u64
}

fn C.__builtin_return_address(int)

pub fn (mut l Lock) acquire() {
	caller := u64(C.__builtin_return_address(0))

	for {
		for i := u64(0); i < u64(100000000); i++ {
			if l.test_and_acquire() == true {
				l.caller = caller
				return
			}
			asm volatile amd64 { pause ;;; memory }
		}
		C.printf(c'POTENTIAL DEADLOCK!!!\n')
		C.printf(c'Lock address:   0x%llx\n', voidptr(l))
		C.printf(c'Current caller: 0x%llx\n', caller)
		C.printf(c'Last caller:    0x%llx\n', l.caller)
		trace.stacktrace(voidptr(0))
	}
}

pub fn (mut l Lock) release() {
	katomic.store(l.l, false)
}

pub fn (mut l Lock) test_and_acquire() bool {
	caller := u64(C.__builtin_return_address(0))

	ret := katomic.cas(l.l, false, true)
	if ret == true {
		l.caller = caller
	}

	return ret
}

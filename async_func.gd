extends Node
## just an example of how it could work...
signal _async_test_completed # Step 1: define a signal
func _async_test() -> void:
	var has_emitted:bool = false # Step 2: track if we have emitted before we've reached the end of the function
	# Add logic as usual...
	for n in 100:
		print(n)
		
		## Step 3: Add condition to finish co-routine
		if n == 99:
			## Simulate long running process that we want to wait for...
			get_tree().create_timer(1).timeout.connect(
			func(): 
				_async_test_completed.emit() ## Step 4: Call the emit
				has_emitted = true
			)
			#_async_test_completed.emit()
			#has_emitted = true
		pass
	print("AWAITING")
	# We only want to await if we've reached the end of the function BEFORE our logic has finished processing.
	if has_emitted == false: await _async_test_completed ## Step 5: at the end of the method, conditionally await the emit
	print("PASSED")
	pass

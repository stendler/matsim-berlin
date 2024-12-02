package org.matsim.profiling;

import jdk.jfr.*;

/**
 * Record a MATSim iteration start and end as a JFR profiling {@link Event}.
 */
@Label("MATSim iteration")
@Description("Event to record the duration of a single iterations")
@Category("MATSim")
public class IterationEvent extends Event {

	@Label("Iteration count")
	@Unsigned
	final int iteration;

	public IterationEvent(int iteration) {
		this.iteration = iteration;
	}
}

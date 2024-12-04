package org.matsim.profiling;

import org.matsim.core.controler.AbstractModule;

/**
 * Start/Stop JFR profiling recordings.
 */
public class ProfilingInstructionModule extends AbstractModule {

	@Override
	public void install() {
		addControlerListenerBinding().to(ProfilingInstructor.class);
	}

}

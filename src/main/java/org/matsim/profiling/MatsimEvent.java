package org.matsim.profiling;

import jdk.jfr.Category;
import jdk.jfr.Description;
import jdk.jfr.Event;
import jdk.jfr.Label;

/**
 * JFR profiling {@link Event} intended as a marker event to record relevant
 * notifications during MATSim execution without a duration.
 */
@Label("MATSim notifications")
@Description("Notifications about startup, shutdown, replanning, and scoring")
@Category("MATSim")
public class MatsimEvent extends Event {

	@Label("Kind of notification")
	final String type;

	public MatsimEvent(String type) {
		this.type = type;
	}

	/**
	 * Factory method to simplify instantiation and usage:
	 * {@code MatsimEvent.create("startup").commit();}.
	 * <p>This avoids using {@code new} and a variable.
	 *
	 * @param type describing the kind of event
	 */
	public static MatsimEvent create(String type) {
		return new MatsimEvent(type);
	}
}

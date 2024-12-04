package org.matsim.profiling;

import com.google.inject.Inject;
import jdk.jfr.Configuration;
import jdk.jfr.Recording;
import org.matsim.api.core.v01.Scenario;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.ControllerConfigGroup;
import org.matsim.core.controler.events.IterationEndsEvent;
import org.matsim.core.controler.events.IterationStartsEvent;
import org.matsim.core.controler.listener.IterationEndsListener;
import org.matsim.core.controler.listener.IterationStartsListener;

import java.io.IOException;
import java.nio.file.Path;
import java.text.ParseException;
import java.util.Map;

/**
 * Start/Stop JFR profiling recordings.
 * todo: order/priority
 * todo: iteration vs just a mobsim? -> a single recording cannot be stopped and restarted again later, so iterations make more sense
 */
public class ProfilingInstructor implements IterationStartsListener, IterationEndsListener {

	private final int startIteration;
	private final int endIteration;
	private final Recording recording;

	@Inject
	public ProfilingInstructor(Scenario scenario) throws IOException, ParseException {
		// todo read from config
		startIteration = 1;
		endIteration = 2;

		if (startIteration < 0 || endIteration < 0 || startIteration > endIteration) {
			throw new IllegalArgumentException("startIteration: " + startIteration + ", endIteration: " + endIteration);
		}

		// todo other configurable filename?
		// todo more than one recording?
		Path outputPath = Path.of(ConfigUtils.addOrGetModule(scenario.getConfig(), ControllerConfigGroup.class).getOutputDirectory(), "profile.jfr");
		this.recording = new Recording(Configuration.getConfiguration("profile"));
		this.recording.setDestination(outputPath);
		this.recording.setToDisk(false); // true might be better for longer recordings? memory usage vs disk IO?
		// todo if disk=true; how to set repository setting here?
		this.recording.setDumpOnExit(true); // in case it exits prematurely?

		System.out.println("[PROFILING] Recording settings");
		for (Map.Entry<String,String> setting : recording.getSettings().entrySet()) {
			System.out.println(setting.getKey() + ": " + setting.getValue());
		}
	}

	@Override
	public void notifyIterationStarts(IterationStartsEvent iterationStartsEvent) {
		if (iterationStartsEvent.getIteration() == startIteration) {
			// start recording
			recording.start();
		}
	}

	@Override
	public void notifyIterationEnds(IterationEndsEvent iterationEndsEvent) {
		if (iterationEndsEvent.getIteration() == endIteration) {
			// stop recording - automatically dumped since output path is set and then closed as well
			recording.stop();
		}
		System.out.println("[PROFILING] " + recording.getState() + " Current iteration: " + iterationEndsEvent.getIteration());
	}
}

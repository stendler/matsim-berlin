package org.matsim.run;

import com.google.inject.Inject;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVPrinter;
import org.matsim.application.MATSimApplication;
import org.matsim.core.config.Config;
import org.matsim.core.controler.AbstractModule;
import org.matsim.core.controler.Controler;
import org.matsim.core.controler.OutputDirectoryHierarchy;
import org.matsim.core.mobsim.framework.events.MobsimBeforeCleanupEvent;
import org.matsim.core.mobsim.framework.events.MobsimInitializedEvent;
import org.matsim.core.mobsim.framework.listeners.MobsimBeforeCleanupListener;
import org.matsim.core.mobsim.framework.listeners.MobsimInitializedListener;
import org.matsim.profiling.ProfilingEventsModule;
import org.matsim.profiling.ProfilingInstructionModule;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.time.Instant;

/**
 * This class runs one iteration of MATSim and tracks the execution time into a csv file.
 */
public class RunQsimComparison extends OpenBerlinScenario {

	public static void main(String[] args) {
		MATSimApplication.run(RunQsimComparison.class, args);
	}

	@Override
	protected Config prepareConfig(Config config) {

		config = super.prepareConfig(config);
		config.controller().setOverwriteFileSetting(OutputDirectoryHierarchy.OverwriteFileSetting.deleteDirectoryIfExists);
		config.controller().setFirstIteration(0);
		config.controller().setLastIteration(0);

		// don't write any events, as this slows down the qsim
		//config.controler().setWriteEventsInterval(0);

		// rust_qsim has no pt
		//config.transit().setUseTransit(false);

		return config;
	}

	@Override
	protected void prepareControler(Controler controler) {

		controler.addOverridingModule(new ProfilingInstructionModule());
		controler.addOverridingModule(new ProfilingEventsModule());
		controler.addOverridingModule(new AbstractModule() {
			@Override
			public void install() {
				addMobsimListenerBinding().to(MobsimTimer.class);
			}
		});
	}

	private static final class MobsimTimer implements MobsimInitializedListener, MobsimBeforeCleanupListener {

		private Instant start;

		@Inject
		private Config config;

		@Inject
		private OutputDirectoryHierarchy outDir;

		public static CSVFormat createWriteFormat(String... header) {
			return CSVFormat.DEFAULT.builder()
				.setHeader(header)
				.setSkipHeaderRecord(false)
				.build();
		}

		@Override
		public void notifyMobsimInitialized(MobsimInitializedEvent e) {
			start = Instant.now();
		}

		@Override
		public void notifyMobsimBeforeCleanup(MobsimBeforeCleanupEvent e) {
			Instant now = Instant.now();
			Duration duration = Duration.between(start, now);
			int size = config.qsim().getNumberOfThreads();
			Path filename = Paths.get(outDir.getOutputFilename("instrument-mobsim.csv"));
			try (var writer = Files.newBufferedWriter(filename); var p = new CSVPrinter(writer, createWriteFormat("timestamp", "func", "duration", "size"))) {
				p.printRecord(Instant.now().getNano(), "org.matsim.core.mobsim.qsim.run", duration.toNanos(), size);
			} catch (IOException ex) {
				throw new RuntimeException(ex);
			}
		}

	}
}

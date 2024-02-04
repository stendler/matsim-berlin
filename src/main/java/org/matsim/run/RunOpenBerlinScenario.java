package org.matsim.run;

import com.google.inject.Key;
import com.google.inject.name.Names;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.matsim.api.core.v01.Scenario;
import org.matsim.api.core.v01.TransportMode;
import org.matsim.application.MATSimApplication;
import org.matsim.application.options.SampleOptions;
import org.matsim.core.config.Config;
import org.matsim.core.config.ConfigUtils;
import org.matsim.core.config.groups.ReplanningConfigGroup;
import org.matsim.core.controler.AbstractModule;
import org.matsim.core.controler.Controler;
import org.matsim.core.replanning.strategies.DefaultPlanStrategiesModule;
import org.matsim.core.router.costcalculators.TravelDisutilityFactory;
import org.matsim.core.router.util.TravelTime;
import org.matsim.core.scoring.functions.ScoringParametersForPerson;
import org.matsim.prepare.RunOpenBerlinCalibration;
import org.matsim.prepare.population.AssignIncome;
import org.matsim.simwrapper.SimWrapperConfigGroup;
import org.matsim.simwrapper.SimWrapperModule;
import picocli.CommandLine;
import playground.vsp.scoring.IncomeDependentUtilityOfMoneyPersonScoringParameters;
import java.util.List;
import org.matsim.run.scoring.VspScoringModule;

@CommandLine.Command(header = ":: Open Berlin Scenario ::", version = RunOpenBerlinScenario.VERSION, mixinStandardHelpOptions = true)
public class RunOpenBerlinScenario extends MATSimApplication {

	private static final Logger log = LogManager.getLogger(RunOpenBerlinCalibration.class);

	public static final String VERSION = "6.1";
	public static final String CRS = "EPSG:25832";
	@CommandLine.Mixin
	private final SampleOptions sample = new SampleOptions(10, 25, 3, 1);

	public RunOpenBerlinScenario() {
		super(String.format("input/v%s/berlin-v%s.config.xml", VERSION, VERSION));
	}

	public static void main(String[] args) {
		MATSimApplication.run(RunOpenBerlinScenario.class, args);
	}

	@Override
	protected Config prepareConfig(Config config) {

		SimWrapperConfigGroup sw = ConfigUtils.addOrGetModule(config, SimWrapperConfigGroup.class);

		if (sample.isSet()) {
			double sampleSize = sample.getSample();

			config.qsim().setFlowCapFactor(sampleSize);
			config.qsim().setStorageCapFactor(sampleSize);

			// Counts can be scaled with sample size
			config.counts().setCountsScaleFactor(sampleSize);
			sw.sampleSize = sampleSize;

			config.controller().setRunId(sample.adjustName(config.controller().getRunId()));
			config.controller().setOutputDirectory(sample.adjustName(config.controller().getOutputDirectory()));
			config.plans().setInputFile(sample.adjustName(config.plans().getInputFile()));
		}

		Activities.addScoringParams(config, true);

		// Required for all calibration strategies
		for (String subpopulation : List.of("person", "freight", "goodsTraffic", "commercialPersonTraffic", "commercialPersonTraffic_service")) {
			config.replanning().addStrategySettings(
				new ReplanningConfigGroup.StrategySettings()
					.setStrategyName(DefaultPlanStrategiesModule.DefaultSelector.ChangeExpBeta)
					.setWeight(1.0)
					.setSubpopulation(subpopulation)
			);

			config.replanning().addStrategySettings(
				new ReplanningConfigGroup.StrategySettings()
					.setStrategyName(DefaultPlanStrategiesModule.DefaultStrategy.ReRoute)
					.setWeight(0.15)
					.setSubpopulation(subpopulation)
			);
		}

		config.replanning().addStrategySettings(
			new ReplanningConfigGroup.StrategySettings()
				.setStrategyName(DefaultPlanStrategiesModule.DefaultStrategy.TimeAllocationMutator)
				.setWeight(0.15)
				.setSubpopulation("person")
		);

		config.replanning().addStrategySettings(
			new ReplanningConfigGroup.StrategySettings()
				.setStrategyName(DefaultPlanStrategiesModule.DefaultStrategy.SubtourModeChoice)
				.setWeight(0.15)
				.setSubpopulation("person")
		);

		return config;
	}

	@Override
	protected void prepareScenario(Scenario scenario) {

		AssignIncome income = new AssignIncome();

		// Calculate the income for each person, in next versions this might also be done during creation of the population
		scenario.getPopulation().getPersons().values().forEach(income::run);

	}

	@Override
	protected void prepareControler(Controler controler) {

		controler.addOverridingModule(new SimWrapperModule());

		controler.addOverridingModule(new TravelTimeBinding());

		controler.addOverridingModule(new VspScoringModule());

	}

	/**
	 * Add travel time bindings for ride and freight modes, which are not actually network modes.
	 */
	public static final class TravelTimeBinding extends AbstractModule {
		@Override
		public void install() {
			addTravelTimeBinding(TransportMode.ride).to(networkTravelTime());
			addTravelDisutilityFactoryBinding(TransportMode.ride).to(carTravelDisutilityFactoryKey());

			addTravelTimeBinding("freight").to(Key.get(TravelTime.class, Names.named(TransportMode.truck)));
			addTravelDisutilityFactoryBinding("freight").to(Key.get(TravelDisutilityFactory.class, Names.named(TransportMode.truck)));

			bind(ScoringParametersForPerson.class).to(IncomeDependentUtilityOfMoneyPersonScoringParameters.class).asEagerSingleton();
		}
	}

}

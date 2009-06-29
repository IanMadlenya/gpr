open Format

open Lacaml.Impl.D
open Lacaml.Io

open Gpr
open Utils

open Test_kernels.SE_iso
open Gen_data

let main () =
  begin try Unix.mkdir "data" 0o755 with _ -> () end;
  write_mat "inputs" training_inputs;
  write_vec "targets" training_targets;
  write_mat "inducing_inputs" inducing_inputs;
  write_float "log_ell" params.Cov_se_iso.Params.log_ell;
  write_float "log_sf2" params.Cov_se_iso.Params.log_sf2;

  let module FITC = FITC.Eval in
  let prep_inducing = FITC.Inducing.Prepared.calc inducing_inputs in
  let inducing = FITC.Inducing.calc kernel prep_inducing in
  let prep_inputs = FITC.Inputs.Prepared.calc prep_inducing training_inputs in
  let inputs = FITC.Inputs.calc inducing prep_inputs in

  let model = FITC.Model.calc inputs ~sigma2:noise_sigma2 in
  printf "model log evidence: %.9f@." (FITC.Model.calc_log_evidence model);

  let trained = FITC.Trained.calc model ~targets:training_targets in
  printf "log evidence: %.9f@." (FITC.Trained.calc_log_evidence trained);

  let sigma2 = FITC.Model.get_sigma2 (FITC.Trained.get_model trained) in
  write_float "sigma2" sigma2;

  let mean_predictor = FITC.Mean_predictor.calc_trained trained in
  let co_variance_predictor = FITC.Co_variance_predictor.calc_model model in
  let means = FITC.Means.calc_induced mean_predictor inputs in
  let inducing_means =
    FITC.Means.Inducing.get (FITC.Means.Inducing.calc trained)
  in
  write_vec "inducing_means" inducing_means;
  let means_vec = FITC.Means.get means in
  write_vec "means" means_vec;

  let mean, variance =
    let input = Mat.col inducing_inputs 5 in
    write_vec "one_inducing" input;
    let prepared = FITC.Input.Prepared.calc prep_inducing input in
    let induced = FITC.Input.calc inducing prepared in
    let mean = FITC.Mean.get (FITC.Mean.calc_induced mean_predictor induced) in
    let variance =
      FITC.Variance.get ~predictive:false
        (FITC.Variance.calc_induced co_variance_predictor ~sigma2 induced)
    in
    mean, variance
  in
  write_float "one_mean" mean;
  write_float "one_variance" variance;

  let variances =
    FITC.Variances.Inducing.get ~predictive:false
      (FITC.Variances.Inducing.calc model)
  in
  write_vec "inducing_variances" variances;

  let variances =
    FITC.Variances.get ~predictive:false
      (FITC.Variances.calc_model_inputs model)
  in
  write_vec "variances" variances;

  let fitc_covariances = FITC.Covariances.calc_model_inputs model in
  let fitc_sampler =
    FITC.Cov_sampler.calc ~predictive:false means fitc_covariances
  in
  let fitc_samples = FITC.Cov_sampler.samples fitc_sampler ~n:3 in
  write_vec "sample1" (Mat.col fitc_samples 1);
  write_vec "sample2" (Mat.col fitc_samples 2);
  write_vec "sample3" (Mat.col fitc_samples 3);

  let module FIC = FIC.Eval in
  let fic_covariances = FIC.Covariances.calc_model_inputs model in
  let fic_sampler =
    FIC.Cov_sampler.calc ~predictive:false means fic_covariances
  in
  let fic_samples = FIC.Cov_sampler.samples fic_sampler ~n:3 in
  write_vec "fic_sample1" (Mat.col fic_samples 1);
  write_vec "fic_sample2" (Mat.col fic_samples 2);
  write_vec "fic_sample3" (Mat.col fic_samples 3)

let () = main ()

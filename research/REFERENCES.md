# References

**Location:** `research/REFERENCES.md`
Machine-readable BibTeX for every entry is in [`references.bib`](references.bib).

The list is grouped by the role each work plays in this repository. Entries were selected because they are peer-reviewed or are the primary specification for a mechanism the experiments exercise.

## Container technology foundations

1. Merkel, D. (2014). Docker: lightweight Linux containers for consistent development and deployment. *Linux Journal*, 2014(239).
2. Felter, W., Ferreira, A., Rajamony, R., & Rubio, J. (2015). An updated performance comparison of virtual machines and Linux containers. *IEEE International Symposium on Performance Analysis of Systems and Software (ISPASS)*, 171–172.
3. Sharma, P., Chaufournier, L., Shenoy, P., & Tay, Y. C. (2016). Containers and virtual machines at scale: A comparative study. *Proceedings of the 17th International Middleware Conference*, Article 1.
4. Manco, F., Lupu, C., Schmidt, F., Mendes, J., Kuenzer, S., Sati, S., Yasukata, K., Raiciu, C., & Huici, F. (2017). My VM is lighter (and safer) than your container. *Proceedings of the 26th Symposium on Operating Systems Principles (SOSP)*, 218–233.
5. Pahl, C., Brogi, A., Soldani, J., & Jamshidi, P. (2019). Cloud container technologies: A state-of-the-art review. *IEEE Transactions on Cloud Computing*, 7(3), 677–692.
6. Casalicchio, E., & Iannucci, S. (2020). The state-of-the-art in container technologies: Application, orchestration and security. *Concurrency and Computation: Practice and Experience*, 32(17), e5668.

## Image distribution, layers and build caching (RQ1–RQ4)

7. Harter, T., Salmon, B., Liu, R., Arpaci-Dusseau, A. C., & Arpaci-Dusseau, R. H. (2016). Slacker: Fast distribution with lazy Docker containers. *14th USENIX Conference on File and Storage Technologies (FAST)*, 181–195.
8. Anwar, A., Mohamed, M., Tarasov, V., Littley, M., Rupprecht, L., Cheng, Y., Zhao, N., Skourtis, D., Warke, A. S., Ludwig, H., Hildebrand, D., & Butt, A. R. (2018). Improving Docker registry design based on production workload analysis. *16th USENIX Conference on File and Storage Technologies (FAST)*, 265–278.
9. Zhao, N., Tarasov, V., Albahar, H., Anwar, A., Rupprecht, L., Skourtis, D., Warke, A. S., Mohamed, M., & Butt, A. R. (2019). Large-scale analysis of the Docker Hub dataset. *IEEE International Conference on Cluster Computing (CLUSTER)*, 1–10.
10. Docker Inc. *Dockerfile reference* and *BuildKit: cache mounts (`RUN --mount=type=cache`)*. https://docs.docker.com/reference/dockerfile/ (accessed 2026-09-27).
11. Google. *Distroless container images*. https://github.com/GoogleContainerTools/distroless (accessed 2026-09-27).

## Empirical studies of Dockerfiles and the container ecosystem

12. Cito, J., Schermann, G., Wittern, J. E., Leitner, P., Zumberi, S., & Gall, H. C. (2017). An empirical analysis of the Docker container ecosystem on GitHub. *IEEE/ACM 14th International Conference on Mining Software Repositories (MSR)*, 323–333.
13. Schermann, G., Zumberi, S., & Cito, J. (2018). Structured information on state and evolution of Dockerfiles on GitHub. *IEEE/ACM 15th International Conference on Mining Software Repositories (MSR)*, 26–29.
14. Xu, T., & Marinov, D. (2018). Mining container image repositories for software configuration and beyond. *IEEE/ACM 40th International Conference on Software Engineering: New Ideas and Emerging Results (ICSE-NIER)*, 49–52.
15. Henkel, J., Bird, C., Lahiri, S. K., & Reps, T. (2020). Learning from, understanding, and supporting DevOps artifacts for Docker. *IEEE/ACM 42nd International Conference on Software Engineering (ICSE)*, 38–49.
16. Lin, C., Nadi, S., & Khazaei, H. (2020). A large-scale data set and an empirical study of Docker images hosted on Docker Hub. *IEEE International Conference on Software Maintenance and Evolution (ICSME)*, 371–381.
17. Wu, Y., Zhang, Y., Wang, T., & Wang, H. (2020). Characterizing the occurrence of Dockerfile smells in open-source software: An empirical study. *35th IEEE/ACM International Conference on Automated Software Engineering (ASE)*, 1006–1018.
18. Eng, K., & Hindle, A. (2021). Revisiting Dockerfiles in open source software over time. *IEEE/ACM 18th International Conference on Mining Software Repositories (MSR)*, 449–459.

## Container security (concepts/06_security)

19. Bui, T. (2015). Analysis of Docker security. *arXiv:1501.02967*.
20. Combe, T., Martin, A., & Di Pietro, R. (2016). To Docker or not to Docker: A security perspective. *IEEE Cloud Computing*, 3(5), 54–62.
21. Shu, R., Gu, X., & Enck, W. (2017). A study of security vulnerabilities on Docker Hub. *Proceedings of the 7th ACM Conference on Data and Application Security and Privacy (CODASPY)*, 269–280.
22. Zerouali, A., Mens, T., Robles, G., & Gonzalez-Barahona, J. M. (2019). On the relation between outdated Docker containers, severity vulnerabilities, and bugs. *IEEE 26th International Conference on Software Analysis, Evolution and Reengineering (SANER)*, 491–501.
23. Sultan, S., Ahmad, I., & Dimitriou, T. (2019). Container security: Issues, challenges, and the road ahead. *IEEE Access*, 7, 52976–52996.

## Orchestration (concepts/08, 11, 12)

24. Verma, A., Pedrosa, L., Korupolu, M., Oppenheimer, D., Tune, E., & Wilkes, J. (2015). Large-scale cluster management at Google with Borg. *Proceedings of the 10th European Conference on Computer Systems (EuroSys)*, Article 18.
25. Burns, B., Grant, B., Oppenheimer, D., Brewer, E., & Wilkes, J. (2016). Borg, Omega, and Kubernetes. *Communications of the ACM*, 59(5), 50–57.

## Measurement methodology and statistics (research/harness)

26. Georges, A., Buytaert, D., & Eeckhout, L. (2007). Statistically rigorous Java performance evaluation. *Proceedings of the 22nd ACM SIGPLAN Conference on Object-Oriented Programming, Systems, Languages, and Applications (OOPSLA)*, 57–76.
27. Mytkowicz, T., Diwan, A., Hauswirth, M., & Sweeney, P. F. (2009). Producing wrong data without doing anything obviously wrong! *Proceedings of the 14th International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS)*, 265–276.
28. Kalibera, T., & Jones, R. (2013). Rigorous benchmarking in reasonable time. *Proceedings of the 2013 International Symposium on Memory Management (ISMM)*, 63–74.
29. Welch, B. L. (1947). The generalization of 'Student's' problem when several different population variances are involved. *Biometrika*, 34(1–2), 28–35.
30. Cohen, J. (1988). *Statistical power analysis for the behavioral sciences* (2nd ed.). Lawrence Erlbaum Associates.
31. Cliff, N. (1993). Dominance statistics: Ordinal analyses to answer ordinal questions. *Psychological Bulletin*, 114(3), 494–509.
32. Efron, B., & Tibshirani, R. J. (1993). *An introduction to the bootstrap*. Chapman & Hall.
33. Press, W. H., Teukolsky, S. A., Vetterling, W. T., & Flannery, B. P. (2007). *Numerical recipes: The art of scientific computing* (3rd ed.). Cambridge University Press. (Section 6.4, incomplete beta function.)

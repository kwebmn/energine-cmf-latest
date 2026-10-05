#!/usr/bin/env php
<?php

use Energine\mail\gears\MailProcessor;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Application;

@date_default_timezone_set('Europe/Kyiv');
error_reporting(E_ALL);

require dirname(__DIR__) . '/vendor/autoload.php';
// the project lives in private/project, htdocs is the ISPConfig document root web/
require_once(dirname(__DIR__) . '/htdocs/bootstrap.php');

E()->getLanguage()->setCurrent(E()->getLanguage()->getDefault());

$console = new Application('Mail processor', '0.1');
$console
    ->register('run')
    ->setDescription('Start mail processor')
    ->setCode(function (InputInterface $input, OutputInterface $output) {
        $output->writeln('Starting mail processor');
        try {
            $processor = new MailProcessor();
            $processor->registerInputInterface($input);
            $processor->registerOutputInterface($output);
            $processor->run();
        } catch (\Throwable $e) {
            $output->writeln('<error>' . $e->getMessage().'</error>');
            return Command::FAILURE;
        }
        return Command::SUCCESS;
    });
$console->run();

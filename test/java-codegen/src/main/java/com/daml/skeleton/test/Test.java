// Copyright (c) 2025 Digital Asset (Switzerland) GmbH and/or its affiliates. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

package com.daml.skeleton.test;

import static java.util.UUID.randomUUID;

import com.daml.ledger.api.v2.*;
import com.daml.ledger.api.v2.CommandServiceGrpc.CommandServiceBlockingStub;
import com.daml.ledger.javaapi.data.*;
import com.daml.ledger.javaapi.data.codegen.Choice;
import com.daml.ledger.javaapi.data.codegen.Created;
import com.daml.ledger.javaapi.data.codegen.Exercised;
import com.daml.ledger.javaapi.data.codegen.Update;
import com.daml.ledger.javaapi.data.codegen.HasCommands;
import com.daml.skeleton.model.main.IOU;
import com.google.common.base.Function;
import com.google.common.collect.BiMap;
import com.google.common.collect.HashBiMap;
import com.google.common.collect.Maps;
import com.google.gson.Gson;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.stub.StreamObserver;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class Test {

  private static final Logger logger = LoggerFactory.getLogger(Test.class);

  // application id used for sending commands
  public static final String APP_ID = "Skeleton";

  public static void main(String[] args) {
    // Extract host and port from arguments
    if (args.length < 3) {
      System.err.println("Usage: LEDGER_HOST LEDGER_PORT PARTY");
      System.exit(-1);
    }
    String ledgerhost = args[0];
    int ledgerport = Integer.valueOf(args[1]);
    String party = args[2];

    // Connect to gRPC services
    ManagedChannel channel =
        ManagedChannelBuilder.forAddress(ledgerhost, ledgerport)
            .maxInboundMessageSize(10485760)
            .usePlaintext()
            .build();

    // From documentation: Create an Asset
    CommandServiceBlockingStub commandService = CommandServiceGrpc.newBlockingStub(channel);
    CommandsSubmission commandsSubmission = CommandsSubmission.create(
      randomUUID().toString(),
      randomUUID().toString(),
      Optional.empty(),
      IOU.create(party, party, 10L, "USDT").commands()
    ).withActAs(party);
    final var createRequest = SubmitAndWaitRequest.toProto(commandsSubmission);
    System.out.println("Submitting create");
    final var createResponse = commandService.submitAndWait(createRequest);
    System.out.println("Created: " + createResponse.toString());

    // Query the asset
    // First find the ledger end
    StateServiceGrpc.StateServiceBlockingStub stateServiceBlockingStub =
    StateServiceGrpc.newBlockingStub(channel);
    long ledgerEnd =
        stateServiceBlockingStub
            .getLedgerEnd(StateServiceOuterClass.GetLedgerEndRequest.newBuilder().build())
            .getOffset();

    System.out.println("Ledger end is: " + ledgerEnd);

    // Then build our filters and do the request
    var contractFilter = IOU.contractFilter();
    var eventFormat = contractFilter.eventFormat(Optional.of(Collections.singleton(party)));
    var queryRequest = new GetActiveContractsRequest(eventFormat, ledgerEnd);
    var activeContracts =
        stateServiceBlockingStub.getActiveContracts(queryRequest.toProto());
    
    System.out.println("Queried contracts");
    
    // Assert the response contains one contract, that belongs to Alice
    var queryResponse = activeContracts.next();
    var contractEntry = GetActiveContractsResponse.fromProto(queryResponse).getContractEntry().get();
    var contract = contractFilter.toContract(contractEntry.getCreatedEvent());
    assert contract.data.owner == party;
    assert !activeContracts.hasNext();
    System.out.println("Found correct contract " + contract.data.toString());

    channel.shutdownNow();
  }
}
